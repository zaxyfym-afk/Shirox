import SwiftUI

// MARK: - Config

/// What the carry-on splash shows: the app's mark over the launch screen's own background,
/// so the two read as one. The launch screen is the generated, contentless one — a plain
/// system background — so the tint is exactly that, and the mark arrives as the app's own.
struct LaunchConfig {
    var logo = Image("ShiroMark")
    var tint = Color(uiColor: .systemBackground)
    var initialDelay: CGFloat = 0.45
    var iconPadding: CGFloat = 30
    var iconSize = CGSize(width: 150, height: 150)
    var iconRadius: CGFloat = 45
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

#if os(iOS)
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

/// First run: the launch screen shrinks into its rounded icon, pushes up, and the
/// onboarding is revealed beneath — already up, not sliding in over a finished splash.
private struct LaunchScreenWithOnBoarding<Content: View>: View {
    var config: LaunchConfig
    @ViewBuilder var onBoarding: Content

    @State private var pushIcon = false
    @State private var animateIcon = false

    var body: some View {
        if #available(iOS 16.0, *) {
            let layout = animateIcon
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(ZStackLayout(alignment: .bottom))
            layout { stage }
        } else if animateIcon {
            // Below 16 there is no animated layout switch: the two layouts trade places
            // inside the same crossfade.
            VStack(spacing: 0) { stage }
        } else {
            ZStack(alignment: .bottom) { stage }
        }
        .task {
            guard !animateIcon else { return }
            try? await nap(Double(config.initialDelay))
            withAnimation(.carryOn(duration: 0.5, bounce: 0.05)) {
                animateIcon = true
                pushIcon = true
            }

            try? await nap(0.15)
            withAnimation(.carryOn(duration: 0.4, bounce: 0)) {
                pushIcon = false
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: animateIcon ? config.iconRadius : 0)
                .fill(config.tint)

            // The mark at the size the launch screen would show it, cross-fading into
            // the resizable one as the icon shrinks — the swap never shows.
            config.logo
                .frame(
                    width: animateIcon ? config.iconSize.width : nil,
                    height: animateIcon ? config.iconSize.height : nil
                )
                .opacity(animateIcon ? 0 : 1)
                .transaction { $0.disablesAnimations = true }
                .overlay {
                    config.logo
                        .resizable().scaledToFit()
                        .opacity(animateIcon ? 1 : 0)
                        .transaction { $0.disablesAnimations = true }
                        .padding(animateIcon ? config.iconPadding : 0)
                }
        }
        .frame(
            width: animateIcon ? config.iconSize.width : nil,
            height: animateIcon ? config.iconSize.height : nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(pushIcon ? 0.95 : 1)
        .offset(y: pushIcon ? 100 : 0)
        .zIndex(1)
        .carryOnGeometryGroup()
        .ignoresSafeArea()

        onBoarding
            .compositingGroup()
            .modifier(OnboardingReveal(animateIcon: animateIcon))
            .zIndex(0)
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
                .offset(y: animateIcon ? 0 : 2000)
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

private extension View {
    /// The presentation-clear background is 16.4's; the cover below that is opaque, so
    /// nothing shows when it's skipped.
    @ViewBuilder
    func clearPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
        } else {
            self
        }
    }

    /// Geometry groups keep the icon's effects together while it shrinks; 17's, and a
    /// nicety — below it the shrink simply runs without one.
    @ViewBuilder
    func carryOnGeometryGroup() -> some View {
        if #available(iOS 17.0, *) {
            self.geometryGroup()
        } else {
            self
        }
    }
}

private extension Animation {
    /// The named springs (`bouncy`, `smooth`) are 17's; the carry-on runs from iOS 15, so
    /// below it the same springs are spelled the old way.
    static func carryOn(duration: Double, bounce: Double) -> Animation {
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
