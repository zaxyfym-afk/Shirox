import SwiftUI

// MARK: - The modifier

extension View {
    /// Pull to refresh whose indicator is a blob that grows out of the Dynamic Island — or the
    /// notch, or the top edge — and pinches off into the spinner. The Gooey style of Settings ›
    /// General › Pull to Refresh, ported from the reference project's MorphingRefreshable.
    ///
    /// It is `.refreshable` underneath — the native control's gesture, trigger and the gap it
    /// holds open — with only its spinner hidden and the blob drawn over it. The frosted circle
    /// (`fallback`) covers the Glass style, the other platforms, and systems before iOS 18,
    /// where the scroll reading the blob needs doesn't exist. Pulls count towards the app's
    /// few-a-minute limit; one over it ends at once and says so.
    func morphingRefreshable(fallback: RefreshFallback = .circle,
                             action: @escaping @Sendable () async -> Void) -> some View {
        modifier(MorphingRefreshModifier(fallback: fallback, action: action))
    }
}

// MARK: - The styles

/// How a full screen shows that it's refreshing.
enum PullToRefreshStyle: String, CaseIterable, Identifiable {
    /// The blob out of the Dynamic Island.
    case gooey
    /// The frosted circle, as sheets have.
    case glass
    /// Pulling still refreshes, with nothing on screen and a haptic when it lands.
    case none

    static let key = "pullToRefreshStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gooey: return String(localized: "settings.gooey")
        case .glass: return String(localized: "settings.glass")
        case .none:  return String(localized: "settings.none")
        }
    }

    /// Before the picker it was the Gooey switch: off meant the circle. Old backups still
    /// carry the switch, so it decides the picker's starting point.
    static var defaultStyle: PullToRefreshStyle {
        UserDefaults.standard.object(forKey: legacySwitchKey) as? Bool == false ? .glass : .gooey
    }

    private static let legacySwitchKey = "gooeyRefresh"
}

/// What a full screen shows when the blob isn't: the Glass style, another platform, or a
/// system before iOS 18.
enum RefreshFallback {
    /// `circleRefreshable`.
    case circle
    /// Nothing from the modifier: the screen draws its own — Home, whose hero holds the circle.
    case custom
}

// MARK: - The blob's rules

/// The blob's numbers, apart from the view: the reference project's, named so they can be
/// tested. `RefreshCircleGeometry` is the same idea for the circle.
enum MorphingRefreshGeometry {
    /// A bar interrupting the top safe area means the blob would draw over it; the native
    /// spinner shows there instead. iPhone Air has the largest top inset so far at 68, so 70
    /// covers it.
    static let barInterruptsBlob: CGFloat = 70

    /// A top inset at least this large means the phone has a Dynamic Island for the blob to
    /// grow out of.
    static let dynamicIslandInset: CGFloat = 59

    /// The pull is all of it by 60 pt, the native control's own scale.
    static func progress(offsetWithInset: CGFloat) -> CGFloat {
        max(0, min(-offsetWithInset / 60, 1))
    }

    /// How far the circle drops, in pt: the pull's share of the drop below the island. Phones
    /// without an island start higher up — the capsule sits at the top edge rather than in the
    /// island's own place — so their circle drops further.
    static func circleOffset(safeAreaTop: CGFloat, progress: CGFloat) -> CGFloat {
        let extra = safeAreaTop >= dynamicIslandInset ? 0 : 15.0
        let base = safeAreaTop < 35 ? safeAreaTop + 35 + 15 : safeAreaTop + extra
        return base * progress
    }

    /// The circle grows from 30 pt across, over the pull's first four fifths.
    static func circleSize(progress: CGFloat) -> CGFloat {
        30 + circleGrowth(progress) * 10
    }

    private static func circleGrowth(_ progress: CGFloat) -> CGFloat {
        progress > 0.2 ? (progress - 0.2) / 0.8 : 0
    }

    /// The spinner's circle reaches full size with the pull.
    static func spinnerSize(progress: CGFloat) -> CGFloat {
        30 + progress * 10
    }

    /// The spinner lands over the pull's last fifth.
    static func spinnerOpacity(progress: CGFloat) -> Double {
        progress > 0.8 ? Double((progress - 0.8) / 0.2) : 0
    }

    /// The shapes blur into each other until the pull is whole, then sit crisp.
    static func blurRadius(progress: CGFloat) -> CGFloat {
        25 - 25 * progress
    }
}

// MARK: - The style router

struct MorphingRefreshModifier: ViewModifier {
    let fallback: RefreshFallback
    nonisolated let action: @Sendable () async -> Void
    @AppStorage(PullToRefreshStyle.key) private var style = PullToRefreshStyle.defaultStyle

    func body(content: Content) -> some View {
        #if os(iOS)
        switch style {
        case .gooey:
            if #available(iOS 18, *) {
                content.modifier(MorphingBlobModifier(action: action))
            } else {
                // The blob reads the pull through iOS 18's scroll geometry callbacks; before
                // that the Gooey pull gets the frosted circle rather than the grey spinner.
                content.circleRefreshable(action: action)
            }
        case .none:
            content.modifier(QuietRefreshModifier(action: action))
        case .glass:
            fallbackContent(content)
        }
        #else
        fallbackContent(content)
        #endif
    }

    @ViewBuilder
    private func fallbackContent(_ content: Content) -> some View {
        switch fallback {
        case .circle: content.circleRefreshable(action: action)
        case .custom: content
        }
    }
}

#if os(iOS)
import UIKit

// MARK: - The None style

/// The None style: pulling still refreshes, with nothing on screen. The native control stays
/// — its gesture and its trigger — with its spinner hidden and a haptic when the refresh
/// lands. The threshold haptic the old drop had went with it: the native control doesn't say
/// how far a pull has come.
private struct QuietRefreshModifier: ViewModifier {
    nonisolated let action: @Sendable () async -> Void

    func body(content: Content) -> some View {
        let action = self.action
        let refresh = RefreshLimiter.shared.limiting {
            await action()
            await MainActor.run { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        return content
            .background(RefreshControlSpinnerHider(hidesSpinner: .constant(true)))
            .refreshable { await refresh() }
    }
}

// MARK: - The blob

/// The Gooey blob: drawn over the content while its pull lasts and — held at a whole pull —
/// while its refresh runs.
@available(iOS 18.0, *)
private struct MorphingBlobModifier: ViewModifier {
    nonisolated let action: @Sendable () async -> Void

    @State private var scrollProgress: CGFloat = 0
    @State private var actualProgress: CGFloat = 0
    @State private var isRefreshing = false
    @State private var isAnimating = false
    /// False when a bar interrupts the top safe area, where the blob would draw over it: the
    /// native spinner shows instead.
    @State private var blobClearsTheBar = true

    func body(content: Content) -> some View {
        let refresh = RefreshLimiter.shared.limiting(action)
        return content
            .background(RefreshControlSpinnerHider(hidesSpinner: $blobClearsTheBar))
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    let safeArea = proxy.safeAreaInsets
                    ZStack {
                        if blobClearsTheBar && scrollProgress != 0 {
                            MorphingBlob(safeAreaTop: safeArea.top, progress: scrollProgress)
                        }
                    }
                    .ignoresSafeArea()
                }
                .frame(height: 1)
                .allowsHitTesting(false)
            }
            .mask { Rectangle().ignoresSafeArea() }
            .refreshable {
                isRefreshing = true
                await refresh()

                if actualProgress == 0 {
                    // The pull is over — the refresh outlasted it, or the list is back at the
                    // top — so the blob shrinks away rather than blinking out.
                    isAnimating = true
                    withAnimation(.easeInOut(duration: 0.2), completionCriteria: .logicallyComplete) {
                        scrollProgress = 0.01
                    } completion: {
                        scrollProgress = 0
                        isAnimating = false
                    }
                }

                isRefreshing = false
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                let progress = MorphingRefreshGeometry.progress(offsetWithInset: offset)
                actualProgress = progress
                // While refreshing the blob holds at a whole pull, whatever the content does.
                if !isAnimating { scrollProgress = isRefreshing ? 1 : progress }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.safeAreaInsets.top < MorphingRefreshGeometry.barInterruptsBlob
            } action: { _, clears in
                blobClearsTheBar = clears
            }
    }
}

/// The metaball itself, following the pull: a capsule in the island's silhouette, the circle
/// dropping out of it, the two blurred into one and re-thresholded on the GPU (that's
/// `AlphaThreshold.metal`) so they join in a neck and pinch apart, and the spinner landing in
/// the circle over the last fifth of the pull.
@available(iOS 18.0, *)
private struct MorphingBlob: View {
    let safeAreaTop: CGFloat
    var progress: CGFloat
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let hasIsland = safeAreaTop >= MorphingRefreshGeometry.dynamicIslandInset
        let offset = MorphingRefreshGeometry.circleOffset(safeAreaTop: safeAreaTop, progress: progress)
        let circleSize = MorphingRefreshGeometry.circleSize(progress: progress)
        let spinnerSize = MorphingRefreshGeometry.spinnerSize(progress: progress)
        Rectangle()
            .fill(.clear)
            .frame(height: safeAreaTop)
            .overlay(alignment: hasIsland ? .center : .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: 100, height: 33)
                    // Hidden from the app switcher's snapshot, like the system's own bars.
                    .opacity(scenePhase == .active ? 1 : 0)
                    .mask { Capsule().padding(.top, 5) }
                    .overlay(alignment: .bottom) {
                        Circle()
                            .fill(.black)
                            .frame(width: circleSize, height: circleSize)
                            .offset(y: offset)
                    }
                    .compositingGroup()
                    .blur(radius: MorphingRefreshGeometry.blurRadius(progress: progress))
                    .visualEffect { [progress] content, proxy in
                        // Crisp shapes once the pull is whole; the neck only while it grows.
                        content.layerEffect(ShaderLibrary.alphaThreshold(),
                                            maxSampleOffset: proxy.size,
                                            isEnabled: progress != 1)
                    }
                    .overlay(alignment: .bottom) {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                            .opacity(MorphingRefreshGeometry.spinnerOpacity(progress: progress))
                            .frame(width: spinnerSize, height: spinnerSize)
                            .offset(y: offset)
                    }
                    // Without an island the capsule starts above the screen's top edge, which
                    // is where the content's own safe area begins.
                    .offset(y: safeAreaTop < 35 ? -35 : 0)
            }
    }
}

// MARK: - Hiding the native spinner

/// Finds the scroll view the modifier sits on and hides its refresh control's spinner while
/// the blob is the one showing. The control itself stays — its gesture, its trigger, the gap
/// it holds open — and the spinner comes back whenever the blob can't show, so a screen whose
/// top safe area a bar interrupts still gets an indicator.
private struct RefreshControlSpinnerHider: UIViewRepresentable {
    @Binding var hidesSpinner: Bool

    func makeCoordinator() -> RefreshSpinnerHiderController { RefreshSpinnerHiderController() }

    func makeUIView(context: Context) -> ScrollViewHookView {
        let view = ScrollViewHookView()
        view.onScrollView = { [weak controller = context.coordinator] scrollView in
            controller?.attach(scrollView)
        }
        return view
    }

    func updateUIView(_ uiView: ScrollViewHookView, context: Context) {
        context.coordinator.hidesSpinner = hidesSpinner
        context.coordinator.hideNow()
    }

    static func dismantleUIView(_ uiView: ScrollViewHookView, coordinator: RefreshSpinnerHiderController) {
        coordinator.detach()
    }
}

@MainActor
final class RefreshSpinnerHiderController: NSObject {
    var hidesSpinner = false
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?

    func attach(_ scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        detach()
        self.scrollView = scrollView
        observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.scrolled() }
        }
        scrolled()
    }

    func detach() {
        observation?.invalidate()
        observation = nil
        scrollView = nil
    }

    func hideNow() {
        guard let scrollView else { return }
        hide(in: scrollView)
    }

    private func scrolled() {
        guard let scrollView else { return }
        hide(in: scrollView)
    }

    /// The spinner's own views, hidden or shown again on every tick: `.refreshable` can hand
    /// the scroll view its control after the hook finds it, iOS 26 draws the spinner grey
    /// whatever the tint, and UIKit can bring it back mid-scroll.
    private func hide(in scrollView: UIScrollView) {
        guard let control = scrollView.refreshControl else { return }
        for view in control.subviews { view.isHidden = hidesSpinner }
    }
}
#endif
