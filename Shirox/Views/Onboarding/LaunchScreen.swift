import SwiftUI

// MARK: - Config

/// What the carry-on splash shows: the app's real logo — the same artwork the home
/// screen icon carries — over the launch screen's own background, so the two read as one.
/// The launch screen is the generated, contentless one — a plain system background — so
/// the tint is exactly that, and the logo arrives as the app's own.
struct LaunchConfig {
    var logo = Image("AppIconRealistic")
    var tint = Color(uiColor: .systemBackground)
    var initialDelay: CGFloat = 0.45
    var iconPadding: CGFloat = 30
    var iconSize = CGSize(width: 150, height: 150)
    var iconRadius: CGFloat = 45
    /// The logo's size while the splash is still holding still, standing in for the launch
    /// screen's own. The asset is a 1024pt master; shown at its natural size it fills the
    /// screen several times over — the zoomed-in first frame the splash had.
    var launchMarkSize: CGFloat = 92
}

// MARK: - Modifier

extension View {
    /// The carry-on from the launch screen: an unanimated cover over the freshly opened
    /// app, indistinguishable from the launch screen for its first moments, that then
    /// either opens up into the app or hands the stage to the onboarding. iOS only — a Mac
    /// and Apple TV keep `SplashView`.
    @ViewBuilder
    func launchScreen<OnBoarding: View>(
        config: LaunchConfig,
        showOnBoarding: Bool,
        onFinished: @escaping () -> Void = {},
        @ViewBuilder onBoarding: () -> OnBoarding
    ) -> some View {
        #if os(iOS)
        modifier(LaunchScreenModifier(
            config: config,
            showOnBoarding: showOnBoarding,
            onFinished: onFinished,
            onBoarding: onBoarding
        ))
        #else
        self
        #endif
    }
}

/// Whether this process has already run the launch reveal, read by the onboarding so the
/// welcome screen's own logo waits for the splash's icon to bow out — the two never on
/// screen at once, so the animated one is the only logo the first launch ever shows.
/// Every platform answers; only iOS ever says yes.
enum LaunchSplash {
    static var playedThisProcess: Bool {
        #if os(iOS)
        SplashGate.hasPresentedThisProcess
        #else
        false
        #endif
    }
}

#if os(iOS)
/// The splash is a once-per-process event. The root the modifier hangs on is rebuilt when
/// the icon pack changes, and a rebuild re-runs `onAppear` — without this gate a
/// mid-session icon change would replay the whole launch reveal. It lives outside the
/// generic modifier: static stored properties aren't supported on generic types.
private final class SplashGate {
    static var hasPresentedThisProcess = false
}

struct LaunchScreenModifier<OnBoarding: View>: ViewModifier {
    var config: LaunchConfig
    var showOnBoarding: Bool
    var onFinished: () -> Void
    @ViewBuilder var onBoarding: OnBoarding

    @State private var addSplash = false



    func body(content: Content) -> some View {
        content
            .onAppear(perform: presentSplash)
            .fullScreenCover(isPresented: $addSplash, onDismiss: onFinished) {
                ZStack {
                    if showOnBoarding {
                        LaunchScreenWithOnBoarding(config: config) {
                            onBoarding
                        }
                    } else {
                        LaunchScreenOnly(config: config)
                            .clearPresentationBackground()
                    }
                }
            }
    }

    /// The cover goes up without an animation: it should look like the launch screen was
    /// still up, not like something arrived on top of the app.
    private func presentSplash() {
        guard !SplashGate.hasPresentedThisProcess else { return }
        SplashGate.hasPresentedThisProcess = true
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                addSplash.toggle()
            }
        }
    }
}

// MARK: - With onboarding

/// First run: the launch screen shrinks into its rounded icon, rides up out of the way, and
/// the onboarding is revealed beneath it full screen — then the icon fades, leaving the
/// onboarding holding the whole display.
///
/// The reveal used to hand the stage to a VStack: the icon's wrapper and the onboarding were
/// both flexible children of one stack, so a full-height onboarding and a greedy icon frame
/// split the screen between them — the icon stranded on the top half, the onboarding
/// compressed into the bottom half. Everything now lives in one ZStack: the onboarding is
/// always full-screen, and the icon is a fixed-size card that shrinks, rides up and leaves.
/// No animated layout switch, no competing flexible frames, and no AnyLayout — this runs the
/// same on the iOS 15 floor as on 26.
private struct LaunchScreenWithOnBoarding<Content: View>: View {
    var config: LaunchConfig
    @ViewBuilder var onBoarding: Content

    @State private var pushIcon = false
    @State private var animateIcon = false
    /// The icon's last act: faded and removed, so the onboarding ends owning the full screen
    /// rather than sharing it with a shrunken splash card.
    @State private var iconFading = false
    @State private var iconGone = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                onBoarding
                    .compositingGroup()
                    .modifier(OnboardingReveal(animateIcon: animateIcon))
                    .zIndex(0)

                if !iconGone {
                    splashCard
                        // The ride up: from the screen's middle to just under the status bar,
                        // wherever the phone's height puts the middle. 110 pt leaves the icon's
                        // top clear of the tallest island or notch (68 pt) on every iPhone.
                        .offset(y: animateIcon
                                ? -(proxy.size.height / 2 - config.iconSize.height / 2 - 110)
                                : 0)
                        .opacity(iconFading ? 0 : 1)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .task {
            guard !animateIcon else { return }
            // Reduce Motion: the reveal is decoration, so it hands the finished
            // composition straight over — onboarding full screen, no icon, no ride.
            if UIAccessibility.isReduceMotionEnabled {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    animateIcon = true
                    iconFading = true
                    iconGone = true
                }
                return
            }
            try? await nap(Double(config.initialDelay))
            withAnimation(.carryOn(duration: 0.5, bounce: 0.05)) {
                animateIcon = true
                pushIcon = true
            }

            try? await nap(0.15)
            withAnimation(.carryOn(duration: 0.4, bounce: 0)) {
                pushIcon = false
            }

            // The onboarding risen and settled, the icon bows out and the reveal ends with
            // the onboarding full screen.
            try? await nap(0.9)
            withAnimation(.easeInOut(duration: 0.35)) {
                iconFading = true
            }
            try? await nap(0.35)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                iconGone = true
            }
        }
    }

    /// The splash card: full-screen while it stands in for the launch screen, then a fixed
    /// rounded icon — the frame and the mark swap inside the one view, so the shrink and the
    /// ride are one animation.
    @ViewBuilder
    private var splashCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: animateIcon ? config.iconRadius : 0)
                .fill(config.tint)

            // The mark at the size the splash shows it while it holds still, cross-fading
            // into the resizable one as the icon shrinks — the swap never shows. Both are
            // resizable and fitted: at the asset's natural 1024pt the still frame filled
            // the whole screen and read as a zoomed-in poster.
            config.logo
                .resizable().scaledToFit()
                .frame(width: animateIcon ? config.iconSize.width : config.launchMarkSize,
                       height: animateIcon ? config.iconSize.height : config.launchMarkSize)
                .opacity(animateIcon ? 0 : 1)
                .transaction { $0.disablesAnimations = true }
                .overlay {
                    config.logo
                        .resizable().scaledToFit()
                        .opacity(animateIcon ? 1 : 0)
                        .transaction { $0.disablesAnimations = true }
                        .padding(animateIcon ? config.iconPadding : 0)
                        .frame(width: animateIcon ? config.iconSize.width : nil,
                               height: animateIcon ? config.iconSize.height : nil)
                }
        }
        .frame(
            width: animateIcon ? config.iconSize.width : nil,
            height: animateIcon ? config.iconSize.height : nil
        )
        .frame(maxWidth: animateIcon ? nil : .infinity,
               maxHeight: animateIcon ? nil : .infinity)
        .scaleEffect(pushIcon ? 0.95 : 1)
        .offset(y: pushIcon ? 100 : 0)
        .carryOnGeometryGroup()
    }
}

/// The onboarding waits beneath the splash, blurred and out of sight, rising with the
/// reveal. `visualEffect` reads its own size for the rise, which is 17's; below, the
/// same rise from a distance that is always past the screen's bottom.
private struct OnboardingReveal: ViewModifier {
    var animateIcon: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.visualEffect { [animateIcon] inner, proxy in
                inner
                    .blur(radius: animateIcon ? 0 : 15)
                    .opacity(animateIcon ? 1 : 0)
                    .offset(y: animateIcon ? 0 : proxy.size.height)
            }
        } else {
            content
                .blur(radius: animateIcon ? 0 : 15)
                .opacity(animateIcon ? 1 : 0)
                .offset(y: animateIcon ? 0 : 2_000)
        }
    }
}

// MARK: - Launch screen only

/// Every other start: the launch screen's background with the mark cut out; the cut-out
/// expands until the whole screen is hole and the app is what's left standing.
private struct LaunchScreenOnly: View {
    var config: LaunchConfig

    @State private var scaleDown = false
    @State private var scaleUp = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                GeometryReader { proxy in
                    let scaleFactor: CGFloat = 4
                    // The cut-out has to be able to grow past the screen's edges before it
                    // lets go of them, so the drawing happens on a canvas four times over.
                    let size = proxy.size
                        .applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))

                    Rectangle()
                        .fill(config.tint)
                        .mask {
                            Rectangle()
                                .overlay {
                                    logo(isMask: true, size: size)
                                }
                        }
                        .overlay {
                            logo(isMask: false, size: size)
                        }
                }
            }
            .ignoresSafeArea()
            .task {
                guard !scaleDown else { return }

                // Reduce Motion: no bounce, no expanding cut-out — the splash hands over
                // after a plain hold, which is the static splash's whole job.
                if UIAccessibility.isReduceMotionEnabled {
                    try? await nap(Double(config.initialDelay) + 0.3)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        dismiss()
                    }
                    return
                }

                // Bounce down
                try? await nap(Double(config.initialDelay))
                withAnimation(.carryOn(duration: 0.3, bounce: 0)) {
                    scaleDown = true
                }

                // Scale & mask up
                try? await nap(0.1)
                withAnimation(.carryOn(duration: 0.6, bounce: 0)) {
                    scaleUp = true
                }

                // The reveal done, the cover goes without an animation of its own.
                try? await nap(0.6)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dismiss()
                }
            }
    }

    @ViewBuilder
    private func logo(isMask: Bool, size: CGSize) -> some View {
        config.logo
            .resizable().scaledToFit()
            // At the splash's own size: the 1024pt asset at its natural size swallowed the
            // screen before the animation ever ran.
            .frame(width: config.launchMarkSize, height: config.launchMarkSize)
            .blendMode(isMask ? .destinationOut : .normal)
            .scaleEffect(scaleDown ? 0.8 : 1)
            .modifier(MaskGrow(scaleUp: scaleUp, isMask: isMask, canvasSize: size))
    }
}

/// The cut-out's logo grows to swallow the canvas. `visualEffect` scales it exactly to
/// the canvas from its measured size, which is 17's; below, a fixed factor that always
/// covers the four-times canvas.
private struct MaskGrow: ViewModifier {
    var scaleUp: Bool
    var isMask: Bool
    var canvasSize: CGSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.visualEffect { [scaleUp] inner, proxy in
                let imageSize = proxy.size
                let scale = max(
                    canvasSize.width / imageSize.width,
                    canvasSize.height / imageSize.height
                )

                return inner
                    .scaleEffect(scaleUp ? scale : 1)
                    .opacity(isMask ? (scaleUp ? 1 : 0) : (scaleUp ? 0 : 1))
            }
        } else {
            content
                .scaleEffect(scaleUp ? 100 : 1)
                .opacity(isMask ? (scaleUp ? 1 : 0) : (scaleUp ? 0 : 1))
        }
    }
}

// MARK: - Availability

extension View {
    /// The presentation-clear background is 16.4's; the cover below that is opaque, so
    /// nothing shows when it's skipped.
    @ViewBuilder
    fileprivate func clearPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
        } else {
            self
        }
    }

    /// Geometry groups keep the icon's effects together while it shrinks; 17's, and a
    /// nicety — below it the shrink simply runs without one.
    @ViewBuilder
    fileprivate func carryOnGeometryGroup() -> some View {
        if #available(iOS 17.0, *) {
            self.geometryGroup()
        } else {
            self
        }
    }
}

extension Animation {
    /// The named springs (`bouncy`, `smooth`) are 17's; the carry-on runs from iOS 15, so
    /// below it the same springs are spelled the old way.
    fileprivate static func carryOn(duration: Double, bounce: Double) -> Animation {
        if #available(iOS 17.0, *) {
            return .bouncy(duration: duration, extraBounce: bounce)
        }
        return .spring(response: duration, dampingFraction: 1 - bounce * 4)
    }
}

/// `Task.sleep(for:)` is 16's; the carry-on runs from iOS 15.
private func nap(_ seconds: Double) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}
#endif
