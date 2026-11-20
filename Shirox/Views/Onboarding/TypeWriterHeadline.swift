import SwiftUI

// MARK: - Config

/// What the typewriter does: how fast it types, how long it lingers, how it wipes away.
struct TypeWriterConfig {
    var font: Font = .system(size: 17, weight: .semibold)
    var caretSize = CGSize(width: 14, height: 2.5)

    var typingDuration: Double = 0.8
    var typingPauseIntensity: PauseIntensity = .full

    var dismissDuration: Double = 0.4
    var dismissPauseIntensity: PauseIntensity = .none

    var textWaitDelay: Double = 1.1
    var nextContentDelay: Double = 0.4

    var initialDelay: Double = 0.8
    var enableTextFading = false

    /// How long each character holds before it appears: none animates every one smoothly,
    /// full snaps each in at its moment.
    enum PauseIntensity: CGFloat {
        case none = 0.0
        case small = 0.15
        case medium = 0.5
        case large = 0.85
        case full = 1.0
    }
}

// MARK: - Headline

/// A headline that types itself out, holds, wipes away, and starts the next phrase — the
/// reference TWTextEffect's engine: a `TextRenderer` revealing the text slice by slice off
/// an animated progress, a blinking caret beside it, a timeline picking the phrase. The
/// per-keystroke haptics the reference also played are left out: the onboarding has none,
/// and the effect carries itself.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct TypeWriterHeadline: View {
    var config: TypeWriterConfig = .init()
    var phrases: [String]

    @State private var startDate: Date?
    @State private var progress: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if let startDate {
                // The timeline loops the phrases: one types out, waits, dismisses, and the
                // next takes over.
                let duration = config.typingDuration + config.textWaitDelay
                    + config.dismissDuration + config.nextContentDelay

                TimelineView(.periodic(from: startDate, by: duration)) { context in
                    let index = Int((startDate.distance(to: context.date) / duration).rounded()) % phrases.count
                    let phrase = phrases[index]

                    HStack(alignment: .bottom, spacing: 0) {
                        Text(phrase)
                            .font(config.font)
                            .textRenderer(TypingTextRenderer(
                                fadeEffect: config.enableTextFading,
                                progress: progress
                            ))
                            // Positioned as though it grew from under the caret.
                            .visualEffect { [progress] content, proxy in
                                let offset = proxy.size.width

                                return content
                                    .offset(x: offset * (1 - progress))
                            }

                        TypingCaret(size: config.caretSize)
                    }
                    // Centred on the width it will have, not the width it has.
                    .visualEffect { [config, progress] content, proxy in
                        let offset = (proxy.size.width - config.caretSize.width) / 2

                        return content
                            .offset(x: -offset * (1 - progress))
                    }
                    .onChange(of: phrase, initial: true) { _, newValue in
                        animatePhrase(newValue)
                    }
                }
            } else {
                // The phrase's place held until it starts, so the page doesn't shift.
                HStack(alignment: .bottom, spacing: 0) {
                    Text(" ")
                        .font(config.font)
                        .frame(width: 0)

                    TypingCaret(size: config.caretSize)
                }
            }
        }
        .lineLimit(1)
        .onChange(of: scenePhase, initial: true) { _, phase in
            Task {
                if phase == .background {
                    startDate = nil
                } else {
                    guard startDate == nil else { return }
                    try? await Task.sleep(for: .seconds(config.initialDelay))
                    startDate = .now
                }
            }
        }
    }

    private func animatePhrase(_ phrase: String) {
        Task {
            withAnimation(.typingAnimation(
                text: phrase,
                pause: config.typingPauseIntensity,
                duration: config.typingDuration
            )) {
                progress = 1
            }

            try? await Task.sleep(for: .seconds(config.typingDuration + config.textWaitDelay))

            withAnimation(.typingAnimation(
                text: phrase,
                pause: config.dismissPauseIntensity,
                duration: config.dismissDuration
            )) {
                progress = 0
            }
        }
    }
}

// MARK: - Caret

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
private struct TypingCaret: View {
    var size: CGSize
    var duration: CGFloat = 0.5
    var delay: CGFloat = 0.1

    var body: some View {
        Rectangle()
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { content, opacity in
                content
                    .opacity(opacity)
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: duration / 2)
                LinearKeyframe(1, duration: delay)
                LinearKeyframe(0, duration: duration / 2)
            }
    }
}

// MARK: - Text renderer

/// Reveals the text slice by slice off the animated progress — a typewriter, not a wipe.
@Animatable
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
private struct TypingTextRenderer: TextRenderer {
    @AnimatableIgnored var fadeEffect: Bool
    var progress: CGFloat

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let slices = layout.flatMap { $0 }.flatMap { $0 }

        for (index, slice) in slices.enumerated() {
            var copy = ctx
            let rawProgress = progress * CGFloat(slices.count) - CGFloat(index)
            let sliceProgress = min(max(rawProgress, 0), 1)

            copy.opacity = fadeEffect ? sliceProgress : sliceProgress.rounded()
            copy.draw(slice)
        }
    }
}

// MARK: - Animation

/// The typing itself: each character has its own moment, held for the pause intensity and
/// then arrived — one progress with real gaps in it, not a smooth crawl.
private struct TypingAnimation: CustomAnimation {
    var text: String
    var pauseIntensity: TypeWriterConfig.PauseIntensity
    var duration: TimeInterval

    nonisolated func animate<V: VectorArithmetic>(
        value: V, time: TimeInterval, context: inout AnimationContext<V>
    ) -> V? {
        let textCount = CGFloat(text.count)
        guard time <= duration else { return nil }

        let timeProgress = time / duration
        let index = floor(timeProgress * textCount)
        let currentProgress = (timeProgress * textCount) - index

        let pause = pauseIntensity.rawValue

        if currentProgress < pause {
            return value.scaled(by: index / textCount)
        }

        let newValue = (index + (currentProgress - pause) / (1 - pause)) / textCount
        return value.scaled(by: newValue)
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
extension Animation {
    static func typingAnimation(
        text: String, pause: TypeWriterConfig.PauseIntensity, duration: TimeInterval
    ) -> Animation {
        Animation(TypingAnimation(text: text, pauseIntensity: pause, duration: duration))
    }
}
