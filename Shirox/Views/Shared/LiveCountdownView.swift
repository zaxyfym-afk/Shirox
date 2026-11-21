import SwiftUI

/// A live countdown to a known instant — the next episode's broadcast — ticking every
/// second while it is on screen. Days, hours, minutes and seconds, each its own tile so
/// the numbers never reflow as they roll. The view that hosts it decides when to hide it:
/// nothing is shown for a past or missing timestamp, and no "Unknown" placeholder exists.
///
/// `TimelineView` drives the tick, so it pauses with the scene and never needs a timer
/// this page would have to hold onto. iOS 15 carries it.
struct LiveCountdownView: View {
    /// The moment being counted down to. Nil, or already past, means "render nothing" —
    /// the caller folds the space away rather than showing a shell.
    let target: Date?
    /// Say what is being counted ("Episode 7 in"), above the tiles, when there is one.
    var caption: LocalizedStringKey? = nil
    /// Compact tiles for rows and cards; the full tiles for a page of their own.
    var compact = false

    var body: some View {
        if let target, target > Date() {
            content(target: target)
        }
    }

    @ViewBuilder
    private func content(target: Date) -> some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            if let caption {
                Text(caption)
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .tracking(compact ? 0.6 : 1.2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, target.timeIntervalSince(context.date))
                HStack(spacing: compact ? 5 : 7) {
                    tile(value: Int(remaining) / 86_400, pad: 2, label: "countdown.days")
                    separator
                    tile(value: Int(remaining) / 3_600 % 24, pad: 2, label: "countdown.hours")
                    separator
                    tile(value: Int(remaining) / 60 % 60, pad: 2, label: "countdown.minutes")
                    separator
                    tile(value: Int(remaining) % 60, pad: 2, label: "countdown.seconds")
                }
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("countdown.a11y \(Int(max(0, target.timeIntervalSinceNow)) / 86_400) \(Int(max(0, target.timeIntervalSinceNow)) / 3_600 % 24) \(Int(max(0, target.timeIntervalSinceNow)) / 60 % 60)"))
        }
    }

    private var separator: some View {
        Text(verbatim: ":")
            .font(compact ? .callout.weight(.bold) : .title3.weight(.bold))
            .foregroundStyle(.tertiary)
    }

    private func tile(value: Int, pad: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: compact ? 1 : 3) {
            Text(verbatim: String(value).leftPad(pad))
                .font(compact ? .subheadline.weight(.bold) : .system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: compact ? 8 : 9, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: compact ? 26 : 42)
    }
}

private extension String {
    /// Zero-padded to at least `width` digits, without format-string ceremony.
    func leftPad(_ width: Int) -> String {
        count >= width ? self : String(repeating: "0", count: width - count) + self
    }
}
