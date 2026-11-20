import Combine
import SwiftUI

enum ToastType {
    case info
    case success
    case error
    case warning

    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    var duration: Double = 3.0
}

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toasts: [Toast] = []

    private init() {}

    /// Most toasts that can ever be on screen at once. Beyond this the oldest are dropped:
    /// a burst (a failing provider, a batch finishing) should read as a stack with a count,
    /// never as a column tall enough to bury the app.
    private static let maxRetained = 4

    func show(message: String, type: ToastType = .info, duration: Double = 3.0) {
        let toast = Toast(message: message, type: type, duration: duration)
        withAnimation(.spring()) {
            toasts.append(toast)
            if toasts.count > Self.maxRetained {
                toasts.removeFirst(toasts.count - Self.maxRetained)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self.remove(toast)
        }
    }

    func remove(_ toast: Toast) {
        withAnimation(.spring()) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

/// Bottom-anchored toast overlay.
///
/// On iOS 26 the toasts are stacked glass capsules — the newest in front, the ones behind
/// peeking out scaled above it, each tinted by what it's about (the reference SToasts).
/// Below 26, and on a Mac and Apple TV, the same stack as cards: full-width glass chrome,
/// a count badge, tap to expand the burst into the list. `ToastManager` — the API every
/// call site knows — is the same in both.
struct ToastView: View {
    @ObservedObject var manager = ToastManager.shared

    var body: some View {
        Group {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 26.0, *) {
                StackedToastLayer()
            } else {
                ClassicToastStack()
            }
            #else
            ClassicToastStack()
            #endif
        }
        .padding(.horizontal, 16)
        // Clear of the tab bar on iOS; a Mac window has none.
        #if os(macOS)
        .frame(maxWidth: 520)
        .padding(.bottom, 24)
        #else
        .padding(.bottom, 88)
        #endif
    }
}

// MARK: - Stacked capsules (iOS 26+)

#if os(iOS) && !targetEnvironment(macCatalyst)
/// The toasts as a stack of glass capsules over a soft-blurred base, pushed and scaled by
/// their place in the stack — a burst reads as depth, not as a column. Ported from the
/// reference SToasts; the stack is a disabled scroll view purely for its geometry, so the
/// cards behind the front one can be laid out by position rather than by hand.
@available(iOS 26.0, *)
private struct StackedToastLayer: View {
    @ObservedObject private var manager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(manager.toasts.reversed()) { toast in
                    let index = manager.toasts.firstIndex(where: { $0.id == toast.id }) ?? 0

                    StackedToastCard(toast: toast) {
                        manager.remove(toast)
                    }
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
                        let progress = minY / 65
                        // Only ever the two cards behind the front one push up.
                        let offset = min(progress * 10, 20)
                        let scale = min(progress * 0.05, 0.1)

                        return content
                            .scaleEffect(1 - scale, anchor: .bottom)
                            .offset(y: -minY)
                            .offset(y: offset)
                    }
                    .zIndex(Double(index))
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(y: 500).combined(with: AnyTransition(.blurReplace)),
                        removal: .move(edge: .leading).combined(with: AnyTransition(.blurReplace))
                    ))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 90)
        // 90 - 65 = 25: the stack's own base, above wherever it's mounted.
        .offset(y: 25 - max(min(CGFloat(manager.toasts.count - 1) * 12.5, 25), 0))
        .background {
            ScrollView(.vertical) { }
                .frame(height: 0)
                .allowsHitTesting(false)
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    Text(" ")
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .opacity(manager.toasts.isEmpty ? 0 : 1)
        }
        .animation(.smooth(duration: 0.3, extraBounce: 0), value: manager.toasts)
        .allowsHitTesting(!manager.toasts.isEmpty)
    }
}

@available(iOS 26.0, *)
private struct StackedToastCard: View {
    let toast: Toast
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            IconView(toast.type.icon)
                .font(.title3)
                .foregroundStyle(toast.type.color.gradient)

            Text(toast.message)
                .font(.callout)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 310, alignment: .leading)
        .frame(minHeight: 65)
        .background {
            // A subtle tint bleed, the Siri bubble's trick: strongest at the card's top,
            // gone by its foot.
            let row1 = Array(repeating: toast.type.color.opacity(0.15), count: 3)
            let row2 = Array(repeating: toast.type.color.opacity(0.1), count: 3)
            let row3 = Array(repeating: Color.clear, count: 3)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: row1 + row2 + row3
            )
            .clipShape(.capsule)
        }
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .compositingGroup()
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 10)
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(toast.message)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("shared.double_tap_to_dismiss")
    }
}
#endif

// MARK: - Cards (below iOS 26, and a Mac and Apple TV)

/// The toasts as cards: the newest in front at full size, the ones behind peeking out
/// above it, a count saying how many. Tapping the stack expands it into the full list;
/// tapping a toast dismisses it.
private struct ClassicToastStack: View {
    @ObservedObject var manager = ToastManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    /// Newest first — the front of the stack is the most recent toast.
    private var stack: [Toast] { manager.toasts.reversed() }
    /// Cards drawn while collapsed. More than three reads as clutter, not depth.
    private static let peekLimit = 3

    var body: some View {
        Group {
            if manager.toasts.isEmpty {
                EmptyView()
            } else if isExpanded || manager.toasts.count == 1 {
                expandedList
            } else {
                collapsedStack
            }
        }
        .animation(motion, value: manager.toasts.map(\.id))
        .animation(motion, value: isExpanded)
        .onChangeOf(manager.toasts.count) { count in
            // Nothing left to expand into — fold back so the next burst starts collapsed.
            if count <= 1 { isExpanded = false }
        }
    }

    private var motion: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)
    }

    // MARK: - Layouts

    private var expandedList: some View {
        VStack(spacing: 8) {
            ForEach(stack) { toast in
                card(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { manager.remove(toast) }
            }
        }
    }

    private var collapsedStack: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(stack.prefix(Self.peekLimit).enumerated()), id: \.element.id) { depth, toast in
                card(toast, badge: depth == 0 ? manager.toasts.count : nil)
                    // Each card behind the front one sits slightly higher and slightly
                    // narrower, so the stack reads as depth rather than as a list.
                    .scaleEffect(1 - CGFloat(depth) * 0.05, anchor: .bottom)
                    .offset(y: -CGFloat(depth) * 9)
                    .opacity(1 - Double(depth) * 0.25)
                    .zIndex(Double(Self.peekLimit - depth))
                    .allowsHitTesting(depth == 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isExpanded = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("shared.notifications \(manager.toasts.count)")
        .accessibilityHint("shared.double_tap_to_show_all")
    }

    // MARK: - Card

    private func card(_ toast: Toast, badge: Int? = nil) -> some View {
        HStack(spacing: 10) {
            IconView(toast.type.icon)
                .foregroundStyle(toast.type.color)
                .font(.system(size: 15, weight: .semibold))
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let badge, badge > 1 {
                Text("\(badge)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassChrome(
            RoundedRectangle(cornerRadius: 16, style: .continuous),
            enabled: true,
            off: .regularMaterial
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}
