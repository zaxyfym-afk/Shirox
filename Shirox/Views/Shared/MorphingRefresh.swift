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

    /// The pull, in points, at which the gooey is whole and the refresh goes. Deliberately
    /// long — near twice the native control's own ~60 pt — so the blob arrives slowly and
    /// has room to stretch while the finger keeps dragging.
    static let pullDistance: CGFloat = 110

    /// The raw pull, 0 to 1 across the whole distance.
    static func progress(offsetWithInset: CGFloat) -> CGFloat {
        max(0, min(-offsetWithInset / pullDistance, 1))
    }

    /// The pull smoothed: slow to start, gathering pace through the middle, easing out at
    /// the end — the gooey materialises gently as the finger drags and stretches
    /// progressively, rather than snapping in over the first few points.
    static func stretch(_ progress: CGFloat) -> CGFloat {
        progress * progress * (3 - 2 * progress)
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
///
/// The blob is anchored to the WINDOW's top edge, not to the scroll view's own safe area.
/// Pages that extend under the status bar (Home's hero, both detail pages) read a zero top
/// inset off their local geometry, and pages under a navigation bar start below the bar:
/// either way a blob positioned from the local insets lands off screen or mid-page. The
/// scroll-view hook reports the window's hardware top inset (the Dynamic Island's own
/// region) and how far the scroll view's top edge sits below the window's top, and the
/// blob shifts up by that distance — so it always grows out of the island, the notch, or
/// the screen's top edge, on every page that can pull.
///
/// The refresh is the modifier's own, not the native control's. `.refreshable` was the
/// source of the trigger jitter: beginning the native control while the list sits at its
/// rest offset shifts the whole content downward by the control's height — the images on a
/// full-bleed page visibly jump the moment the haptic lands — and it kept a gap open under
/// the status bar for the control it hid. Here the pull is read straight off the scroll
/// geometry and run through an explicit state machine (`idle`, `refreshing`, `completing`):
/// the trigger fires only from `idle`, one haptic marks the crossing, and the machine
/// returns to `idle` only once the refresh has finished AND the pull is back at rest — so
/// holding the pull or dragging on after a fast refresh can never re-arm the trigger, and
/// the haptic can never spam.
@available(iOS 18.0, *)
private struct MorphingBlobModifier: ViewModifier {
    nonisolated let action: @Sendable () async -> Void

    /// The refresh's own state machine. One refresh per pull: the trigger fires only from
    /// `idle`, and the machine returns to `idle` only once BOTH the refresh cycle has
    /// finished AND the pull has come back to rest — so holding the pull, or dragging
    /// further, can never re-arm the trigger and spam the haptic.
    private enum Phase {
        /// At rest. The only state the trigger may fire from.
        case idle
        /// The refresh is running. Held here however the finger moves afterwards.
        case refreshing
        /// The refresh finished while the finger was still down: the blob holds its whole
        /// pull until the gesture ends, then shrinks. Not re-armed.
        case completing
    }
    @State private var phase: Phase = .idle

    /// What the blob draws: the pull, smoothed, so the gooey grows progressively.
    @State private var scrollProgress: CGFloat = 0
    /// The raw pull, 0 to 1 across the whole distance, ahead of any smoothing.
    @State private var actualProgress: CGFloat = 0
    /// True while the shrink-back animation runs, so geometry ticks don't fight it.
    @State private var isAnimating = false
    /// The window's hardware top inset: the island's region on the phones that have one,
    /// the notch's on those, the status bar's height elsewhere. Zero on a landscape phone
    /// or a pad, where the blob grows from the bare top edge.
    @State private var windowSafeTop: CGFloat = 0
    /// How far the scroll view's top edge sits below the window's top: zero on the pages
    /// that run under the status bar, the bar's height on the pages that don't.
    @State private var scrollTopInWindow: CGFloat = 0

    func body(content: Content) -> some View {
        let refresh = RefreshLimiter.shared.limiting(action)
        return content
            .background(
                RefreshControlSpinnerHider(hidesSpinner: .constant(true)) { safeTop, topOffset in
                    windowSafeTop = safeTop
                    scrollTopInWindow = topOffset
                }
            )
            .overlay(alignment: .top) {
                GeometryReader { _ in
                    ZStack {
                        if scrollProgress != 0 {
                            MorphingBlob(safeAreaTop: windowSafeTop, progress: scrollProgress)
                                // Up from the scroll view's top edge to the window's top, so the
                                // capsule sits in the island however the page is laid out.
                                .offset(y: -scrollTopInWindow)
                        }
                    }
                    .ignoresSafeArea()
                }
                .frame(height: 1)
                .allowsHitTesting(false)
            }
            .mask { Rectangle().ignoresSafeArea() }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                let pull = MorphingRefreshGeometry.progress(offsetWithInset: offset)
                actualProgress = pull

                switch phase {
                case .idle:
                    // The pull crossing the whole distance IS the trigger — one refresh per
                    // crossing, and only from here. While refreshing, completing or the
                    // shrink's tail, crossings do nothing at all.
                    if !isAnimating, pull >= 1 {
                        beginRefresh(refresh)
                    } else if !isAnimating {
                        scrollProgress = MorphingRefreshGeometry.stretch(pull)
                    }

                case .refreshing:
                    // The refresh owns the blob: held at a whole pull whatever the content
                    // and the finger do, so a hold or a further drag can't re-trigger.
                    scrollProgress = 1

                case .completing:
                    // Refresh done, finger still down: hold whole until the pull returns to
                    // rest, then shrink away. Not before — that is what kept re-arming.
                    if pull <= 0 {
                        shrinkAway()
                    } else {
                        scrollProgress = 1
                    }
                }
            }
    }

    /// One refresh: the haptic, the blob held whole, the work, and the state it ends in —
    /// called only from `idle`, so there is exactly one haptic and one refresh per pull.
    private func beginRefresh(_ refresh: @escaping @Sendable () async -> Void) {
        phase = .refreshing
        scrollProgress = 1
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        Task { @MainActor in
            await refresh()

            // The work is over. Finger gone (the list is back at its rest offset): shrink
            // now. Finger still down holding the pull: stay held, whole, until the pull
            // returns to rest — the geometry tick will call the shrink.
            if actualProgress <= 0 {
                shrinkAway()
            } else {
                phase = .completing
            }
        }
    }

    /// The smooth way back to `idle`: the blob shrinks, and only once it has is the
    /// trigger armed again. The geometry tick that started the shrink keeps arriving while
    /// it runs, so a second call does nothing — the animation must run once, to its end.
    private func shrinkAway() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.easeInOut(duration: 0.2), completionCriteria: .logicallyComplete) {
            scrollProgress = 0.01
        } completion: {
            scrollProgress = 0
            isAnimating = false
            phase = .idle
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

/// Finds the scroll view the modifier sits on, hides its refresh control's spinner while
/// the blob is the one showing, and reports the window metrics the blob draws from.
/// The control itself stays — its gesture, its trigger, the gap it holds open.
private struct RefreshControlSpinnerHider: UIViewRepresentable {
    @Binding var hidesSpinner: Bool
    /// The window's hardware top inset and the scroll view's top edge's distance below the
    /// window's top, re-read on every scroll tick the controller sees.
    var onWindowMetrics: (CGFloat, CGFloat) -> Void = { _, _ in }

    func makeCoordinator() -> RefreshSpinnerHiderController { RefreshSpinnerHiderController() }

    func makeUIView(context: Context) -> ScrollViewHookView {
        let view = ScrollViewHookView()
        view.onScrollView = { [weak controller = context.coordinator] scrollView in
            controller?.attach(scrollView)
            controller?.readWindowMetrics(scrollView)
        }
        return view
    }

    func updateUIView(_ uiView: ScrollViewHookView, context: Context) {
        context.coordinator.hidesSpinner = hidesSpinner
        context.coordinator.onWindowMetrics = onWindowMetrics
        context.coordinator.hideNow()
    }

    static func dismantleUIView(_ uiView: ScrollViewHookView, coordinator: RefreshSpinnerHiderController) {
        coordinator.detach()
    }
}

@MainActor
final class RefreshSpinnerHiderController: NSObject {
    var hidesSpinner = false
    var onWindowMetrics: (CGFloat, CGFloat) -> Void = { _, _ in }
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
        readWindowMetrics(scrollView)
    }

    /// The hardware top inset straight from the window — never the scroll view's own,
    /// which a full-bleed page zeroes and a bar-padded page inflates — and how far the
    /// scroll view's top edge sits below the window's top. A pull moves the content, not
    /// the scroll view's frame, so both hold steady while the blob is out.
    func readWindowMetrics(_ scrollView: UIScrollView) {
        guard let window = scrollView.window else { return }
        let safeTop = window.safeAreaInsets.top
        let topOffset: CGFloat
        if let superview = scrollView.superview {
            topOffset = superview.convert(scrollView.frame, to: nil).minY
        } else {
            topOffset = 0
        }
        onWindowMetrics(safeTop, max(0, topOffset))
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
