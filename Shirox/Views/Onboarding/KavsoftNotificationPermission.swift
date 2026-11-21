import SwiftUI

// MARK: - Kavsoft NotificationPermissionView port (CompactNotificationView example)
//
// Port of the Kavsoft notification permission component: three notification cards rise one
// by one into a stack (a keyframed loop), then the whole stack blurs and lifts away while
// the bell underneath fills its badge — under a title, a one-line benefit and the Enable
// action. The example's notification previews drew an image asset the Shirox bundle doesn't
// carry, so each card renders its app-symbol tile instead; `glassEffect` (iOS 26) falls
// back to a plain material, `onGeometryChange` (iOS 18) to a fixed radius, and the whole
// animation collapses to a calm static stack below iOS 17.
//
// The view embeds inline — onboarding's notifications page — rather than presenting as a
// sheet; the example's sheet presentation modifiers are the caller's business here.

/// Config: the words and the three notification previews the stack animates.
struct KavsoftNotificationPermissionConfig {
    var title: String = String(localized: "onboarding.notifications_title")
    var description: String = String(localized: "onboarding.notifications_body")
    var tint: Color = .accentColor
    var primaryButtonTitle: String = String(localized: "onboarding.enable_notifications")
    var secondaryButtonTitle: String = String(localized: "onboarding.maybe_later")
    var showsSecondaryButton: Bool = true

    /// Notification previews. The example showed an image asset per card; Shirox draws an
    /// app-symbol tile instead, with the same rounded-square silhouette.
    var topNotification: Preview = .init(symbol: "bell.badge.fill", title: "Shirox", caption: "EP 8 aired just now")
    var centerNotification: Preview = .init(symbol: "tv.fill", title: "Frieren", caption: "EP 8 — follow along")
    var bottomNotification: Preview = .init(symbol: "sparkles", title: "Shirox", caption: "New episode available")

    struct Preview {
        var symbol: String
        var title: String
        var caption: String
    }
}

struct KavsoftNotificationPermissionView: View {
    var config: KavsoftNotificationPermissionConfig = .init()
    var primaryAction: () -> Void
    var secondaryAction: () -> Void

    /// View properties
    @State private var containerCornerRadius: CGFloat = 15
    @Environment(\.horizontalSizeClass) private var hClass
    @Environment(\.verticalSizeClass) private var vClass
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
                AnimatedStack(config: config, containerCornerRadius: containerCornerRadius)
            } else {
                StaticStack(config: config, containerCornerRadius: containerCornerRadius)
            }

            contents
        }
        .padding([.horizontal, .top], 15)
        .padding(.bottom, 20)
    }

    /// Text and actions, as the example drew them.
    @ViewBuilder
    private var contents: some View {
        VStack(spacing: 10) {
            Text(config.title)
                .font(.title3.bold())
                .lineLimit(1)

            Text(config.description)
                .multilineTextAlignment(.center)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)

            Button(action: primaryAction) {
                Text(config.primaryButtonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.9))
                    )
                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 15)
            .padding(.horizontal, 15)

            if config.showsSecondaryButton {
                Button(config.secondaryButtonTitle, action: secondaryAction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(config.tint)
    }
}

// MARK: - The animated stack (iOS 17+)

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
private struct AnimatedStack: View {
    let config: KavsoftNotificationPermissionConfig
    let containerCornerRadius: CGFloat

    var body: some View {
        KeyframeAnimator(initialValue: CGFloat.zero, repeating: true) { progress in
            /// Dismiss progress
            let dismissProgress = progress > 3.2 ? (progress - 3.2) / 0.8 : 0

            VStack(spacing: 15) {
                stack(progress)
                    .compositingGroup()
                    .visualEffect { content, proxy in
                        content
                            .blur(radius: 20 * dismissProgress)
                            .opacity(1 - dismissProgress)
                            .offset(y: -proxy.size.height * dismissProgress)
                    }

                bell(progress, dismissProgress)
            }
        } keyframes: { _ in
            /// 0-3 notification keyframes, 3-4 resetting
            MoveKeyframe(0)
            LinearKeyframe(0, duration: 0.5)
            SpringKeyframe(1, duration: 1, spring: .bouncy(duration: 0.9, extraBounce: 0.1))
            SpringKeyframe(2, duration: 1, spring: .bouncy(duration: 0.9, extraBounce: 0.1))
            SpringKeyframe(3, duration: 1, spring: .bouncy(duration: 0.9, extraBounce: 0.1))
            /// Delay before resetting
            LinearKeyframe(3, duration: 1)
            SpringKeyframe(4, duration: 1, spring: .bouncy(duration: 0.9, extraBounce: 0))
        }
    }

    /// Notifications stack
    @ViewBuilder
    private func stack(_ progress: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let notification = index == 0 ? config.bottomNotification
                    : index == 1 ? config.centerNotification
                    : config.topNotification
                /// Animation values
                let indexProgress = progress - CGFloat(index)
                let shown = max(min(indexProgress, 1), 0)

                let offset = 10 * max(indexProgress - 1, 0)
                let scale = 1 - max(indexProgress - 1, 0) * 0.05

                card(notification)
                    .compositingGroup()
                    .opacity(shown)
                    .scaleEffect(0.7 + (shown * 0.3))
                    .scaleEffect(scale, anchor: .bottom)
                    .blur(radius: 10 * (1 - shown))
                    .offset(y: -100 * (1 - shown))
                    .offset(y: offset)
            }
        }
    }

    /// Notification view — the example's glass card, material-backed below iOS 26.
    @ViewBuilder
    private func card(_ value: KavsoftNotificationPermissionConfig.Preview) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.75), .accentColor],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: value.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(value.title)
                    .font(.callout)

                Text(value.caption)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .frame(height: 60)
        .modifier(NotificationCardSurface(cornerRadius: containerCornerRadius))
    }

    /// Bell symbol view
    @ViewBuilder
    private func bell(_ progress: CGFloat, _ dismissProgress: CGFloat) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let symbolSize = size.height / 2

            /// Animation values
            let offsetProgress = 1 - (min(progress / 3, 1) - dismissProgress)
            let opacity = min(progress, 1) - dismissProgress
            let count = max(min(Int(progress.rounded()), 3), 1)

            ZStack {
                Image(systemName: "bell")
                    .font(.system(size: symbolSize))
                    .foregroundStyle(.gray)
                    .opacity(1 - opacity)

                Image(systemName: "bell.badge")
                    .font(.system(size: symbolSize))
                    .foregroundStyle(.red, .gray)
                    .overlay(alignment: .topTrailing) {
                        let fontSize = symbolSize * 0.2

                        Text("\(count)")
                            .font(.system(size: fontSize, weight: .bold))
                            .fontDesign(.rounded)
                            .frame(width: fontSize)
                            .fixedSize()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.linear, value: count)
                            .offset(x: -fontSize * 1.1, y: fontSize * 0.98)
                    }
                    .compositingGroup()
                    .opacity(opacity)
            }
            .compositingGroup()
            .offset(y: -30 * offsetProgress)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 90)
    }
}

/// The card's surface: glass where the OS has it, quiet material where it doesn't.
private struct NotificationCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - The static stack (below iOS 17)

private struct StaticStack: View {
    let config: KavsoftNotificationPermissionConfig
    let containerCornerRadius: CGFloat
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    if index < shown {
                        Card(config: config, index: index, containerCornerRadius: containerCornerRadius)
                            .offset(y: -CGFloat(index) * 8)
                    }
                }
            }
            .frame(height: 120)

            Image(systemName: shown >= 3 ? "bell.badge" : "bell")
                .font(.system(size: 40))
                .foregroundStyle(shown >= 3 ? Color.red : Color.gray)
                .frame(height: 90)
        }
        .task {
            guard !reduceMotion else { shown = 3; return }
            for step in 1...3 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { shown = step }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private struct Card: View {
        let config: KavsoftNotificationPermissionConfig
        let index: Int
        let containerCornerRadius: CGFloat

        private var preview: KavsoftNotificationPermissionConfig.Preview {
            index == 0 ? config.bottomNotification : index == 1 ? config.centerNotification : config.topNotification
        }

        var body: some View {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.accentColor.opacity(0.75), .accentColor],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: preview.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.callout)
                    Text(preview.caption)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .frame(height: 60)
            .modifier(NotificationCardSurface(cornerRadius: containerCornerRadius))
        }
    }
}
