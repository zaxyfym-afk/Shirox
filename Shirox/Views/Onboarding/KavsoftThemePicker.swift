import SwiftUI

// MARK: - Kavsoft ThemePicker port (ATPicker example, Balaji Venkatesh)
//
// Port of the Kavsoft "ATPicker" appearance picker: an animated sky that morphs between day
// and night — sun and moon trading places on a rotating path, stars and a shooting star out
// at night, clouds dissolving into blur at dawn, hills and a lit house below — under a
// segmented Light/Dark/System control whose capsule slides with matched geometry. The pick
// applies the moment it's tapped.
//
// Differences from the original, on purpose: the color set comes from the example's asset
// catalog, inlined here so Shirox carries no duplicate catalog; the sun's continuous
// keyframe spin and the shooting star are iOS 17+ and degrade to static placement below;
// `ConcentricRectangle` (iOS 26) falls back to a rounded rect; `Color.mix` is replaced with
// a plain channel lerp so iOS 17 builds. The value binding is Shirox's own `AppColorScheme`,
// so the picker writes the same preference Settings writes.

/// The example's sky palette, from ATPicker's "Theme Colors" asset catalog.
private extension Color {
    static var kavDarkTop: Color { Color(red: 0.027, green: 0.043, blue: 0.141) }
    static var kavDarkBottom: Color { Color(red: 0.169, green: 0.184, blue: 0.431) }
    static var kavLightTop: Color { Color(red: 0.365, green: 0.706, blue: 1.000) }
    static var kavLightBottom: Color { Color(red: 0.839, green: 0.933, blue: 1.000) }
    static var kavMoon: Color { Color(red: 1.000, green: 0.984, blue: 0.918) }
    static var kavHillTopDark: Color { Color(red: 0.165, green: 0.196, blue: 0.439) }
    static var kavHillTopLight: Color { Color(red: 0.725, green: 0.878, blue: 0.690) }
    static var kavHillCenterDark: Color { Color(red: 0.118, green: 0.149, blue: 0.337) }
    static var kavHillCenterLight: Color { Color(red: 0.525, green: 0.788, blue: 0.541) }
    static var kavHillBottomDark: Color { Color(red: 0.078, green: 0.102, blue: 0.239) }
    static var kavHillBottomLight: Color { Color(red: 0.310, green: 0.647, blue: 0.416) }

    /// The example uses `Color.mix(with:by:)`; a plain lerp keeps the same blends on iOS 17.
    func kavMix(with other: Color, by fraction: CGFloat) -> Color {
        let a = kavComponents(self), b = kavComponents(other)
        return Color(red: a.r + (b.r - a.r) * fraction,
                     green: a.g + (b.g - a.g) * fraction,
                     blue: a.b + (b.b - a.b) * fraction)
    }

    private func kavComponents(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        #if canImport(UIKit)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: nil)
        #elseif canImport(AppKit)
        NSColor(color).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: nil)
        #else
        (r, g, b) = (0.5, 0.5, 0.5)
        #endif
        return (r, g, b)
    }
}

/// The picker itself: the animated preview, the segmented control and the caption. Embed it
/// inline (onboarding's appearance page) — the original presented it as a sheet; the content
/// is identical either way.
struct KavsoftThemePicker: View {
    @Binding var value: AppColorScheme
    var envColorScheme: ColorScheme
    @State private var isDark: Bool
    @Namespace private var animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(value: Binding<AppColorScheme>, envColorScheme: ColorScheme) {
        self._value = value
        self.envColorScheme = envColorScheme
        _isDark = State(initialValue: envColorScheme == .dark)
    }

    var body: some View {
        VStack(spacing: 15) {
            AnimatedPreview()
                .frame(height: 200)

            ThemeSegmentedControl()

            Text(value.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .animation(Self.smoothAnimation, value: value)
        }
        .padding(.horizontal, 15)
        /// Updating status based on the environment scheme, not the value itself — the sky
        /// follows what the app actually turned into.
        .modifier(ThemePickerChangeObserver(colorScheme: envColorScheme) { newValue in
            let nowDark = newValue == .dark
            DispatchQueue.main.async {
                withAnimation(.interpolatingSpring(duration: 1, bounce: 0, initialVelocity: 0)) {
                    isDark = nowDark
                }
            }
        })
    }

    /// iOS 17's smooth spring, approximated by a plain spring below.
    static var smoothAnimation: Animation {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return .smooth(duration: 0.45, extraBounce: 0)
        }
        return .spring(response: 0.45, dampingFraction: 0.85)
    }

    static var bouncyAnimation: Animation {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return .bouncy(duration: 0.5, extraBounce: 0.1)
        }
        return .spring(response: 0.5, dampingFraction: 0.7)
    }

    /// The two-parameter `onChange` on iOS 17+, the one-parameter form below.
    private struct ThemePickerChangeObserver: ViewModifier {
        let colorScheme: ColorScheme
        let action: (ColorScheme) -> Void

        func body(content: Content) -> some View {
            if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
                content.onChange(of: colorScheme) { _, newValue in action(newValue) }
            } else {
                content.onChange(of: colorScheme) { newValue in action(newValue) }
            }
        }
    }

    // MARK: Animated Preview

    @ViewBuilder
    private func AnimatedPreview() -> some View {
        GeometryReader {
            let size = $0.size
            let gradientColors: [Color] = isDark
                ? [.kavDarkTop, .kavDarkBottom]
                : [.kavLightTop, .kavLightBottom]

            ZStack {
                LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)

                // Stars only at night.
                StarsView(count: 15)
                    .opacity(isDark ? 1 : 0)

                // Sun and moon trading places around the sky's edge.
                ZStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.kavMoon)
                        .shadow(color: Color.kavMoon.opacity(0.6), radius: 15)
                        .rotationEffect(.degrees(isDark ? -130 : 0))
                        .frame(width: size.width, height: size.width)
                        .offset(x: -(size.width - 40) / 2)
                        .rotationEffect(.degrees(isDark ? 130 : -30))
                        .offset(y: 10)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 85, weight: .ultraLight))
                        .foregroundStyle(.yellow)
                        .shadow(color: .white, radius: 15)
                        .compositingGroup()
                        .modifier(SunSpinModifier())
                        .frame(width: size.width, height: size.width)
                        .offset(x: -(size.width - 40) / 2)
                        .rotationEffect(.degrees(isDark ? 200 : 130))
                        .offset(y: 10)
                }
                .frame(width: size.width, height: size.height, alignment: .top)

                // Shooting star, dark mode only (KeyframeAnimator needs iOS 17).
                if isDark {
                    if #available(iOS 17.0, *) {
                        ShootingStar()
                    }
                }

                // Clouds dissolve into blur as night falls.
                HStack(spacing: 0) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? -100 : 0, y: -30)

                    Spacer(minLength: 0)

                    Image(systemName: "cloud.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? 100 : 0)

                    Spacer(minLength: 0)

                    Image(systemName: "cloud.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? 100 : 0, y: 35)
                }
                .padding(.horizontal, 20)
                .compositingGroup()
                .blur(radius: isDark ? 30 : 0)
                .opacity(isDark ? 0 : 1)

                // Ground layers and the house with its light on.
                ZStack {
                    GroundShape(density: 0.5)
                        .fill(isDark ? Color.kavHillTopDark : Color.kavHillTopLight)

                    GroundShape(density: 0.35)
                        .fill(isDark ? Color.kavHillCenterDark : Color.kavHillCenterLight)

                    GroundShape(density: 0.2)
                        .fill(isDark ? Color.kavHillBottomDark : Color.kavHillBottomLight)

                    Image(systemName: "house.lodge.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.black.kavMix(with: .white, by: isDark ? 0.1 : 0.4))
                        .background(alignment: .bottom) {
                            Circle()
                                .fill(.yellow.opacity(isDark ? 1 : 0))
                                .frame(width: 12, height: 12)
                                .shadow(color: .yellow.opacity(isDark ? 1 : 0), radius: 5)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .offset(x: 50, y: -120 * 0.37)
                }
                .frame(height: 100)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipShape(previewShape)
        .animation(reduceMotion ? nil : .interpolatingSpring(duration: 1, bounce: 0, initialVelocity: 0),
                   value: isDark)
    }

    private var previewShape: some Shape {
        // AnyShape can't be built below iOS 16, so the concentric (iOS 26) look
        // falls back to the same continuous rounded rect on every version.
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    // MARK: Segmented control

    @ViewBuilder
    private func ThemeSegmentedControl() -> some View {
        HStack(spacing: 0) {
            ForEach([AppColorScheme.light, .dark, .system], id: \.self) { scheme in
                let isSelected = value == scheme
                let tintColor: Color = isDark ? .indigo : .yellow.kavMix(with: .orange, by: 0.2)
                let rotation: CGFloat = scheme == .light ? 180
                    : scheme == .dark ? -15
                    : (isDark ? 180 : 0)

                HStack(spacing: 8) {
                    Image(systemName: scheme.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? tintColor : (isDark ? .white : .black))
                        .environment(\.colorScheme, .light)
                        .rotationEffect(.degrees(isSelected ? rotation : 0))

                    Text(scheme.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .environment(\.colorScheme, .light)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        ZStack {
                            Capsule()
                                .fill(isDark ? Color.black : Color.white)

                            Capsule()
                                .stroke(tintColor, lineWidth: 1.5)
                                .padding(0.5)
                        }
                        .compositingGroup()
                        .shadow(color: tintColor.opacity(0.3), radius: 10)
                        .matchedGeometryEffect(id: "CAPSULE", in: animation)
                    }
                }
                .onTapGesture {
                    guard value != scheme else { return }
                    value = scheme
                    AppColorScheme.apply()
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }
            }
        }
        .frame(height: 40)
        .padding(4)
        .background(.gray.opacity(0.15), in: .capsule)
        .animation(Self.bouncyAnimation, value: value)
    }
}

/// The sun's continuous spin, a `keyframeAnimator` on iOS 17+ and still elsewhere.
private struct SunSpinModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            content
                .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { c, rotation in
                    c.rotationEffect(.degrees(rotation))
                } keyframes: { _ in
                    LinearKeyframe(360, duration: 60)
                }
        } else {
            content
        }
    }
}

/// The shooting star: a keyframed capsule streak, iOS 17+ only, absent below.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
private struct ShootingStar: View {
    var body: some View {
        KeyframeAnimator(initialValue: CGFloat.zero, repeating: true) { offset in
            let opacity = max(min(offset / 200, 1), 0)
            Capsule()
                .fill(LinearGradient(colors: [
                    Color.kavMoon,
                    Color.kavMoon.opacity(0.5),
                    Color.kavMoon.opacity(0.3),
                    Color.kavMoon.opacity(0.3),
                    .clear
                ], startPoint: .trailing, endPoint: .leading))
                .frame(width: 100, height: 2)
                .offset(x: offset, y: 25)
                .rotationEffect(.degrees(25))
                .opacity(1 - opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } keyframes: { _ in
            MoveKeyframe(-100)
            LinearKeyframe(-100, duration: 1.5)
            CubicKeyframe(200, duration: 1.8)
            LinearKeyframe(200, duration: 3)
        }
    }
}

/// The example's deterministic star field.
private struct StarsView: View {
    var count: Int

    var body: some View {
        Canvas { context, size in
            for i in 0..<count {
                let x = random(i, 1) * size.width
                let y = random(i, 2) * size.height
                let starSize = random(i, 3) > 0.66 ? 3.0 : 2.0
                let opacity = 0.5 + random(i, 4) * 0.5
                let star = Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize))
                context.fill(star, with: .color(.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    private func random(_ i: Int, _ seed: Double) -> Double {
        let value = sin(Double(i) * 22.5 + seed * 99.2) * 43.6
        return value - value.rounded(.down)
    }
}

/// The example's rolling hills.
private struct GroundShape: Shape {
    var density: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let base = height * (1 - density)
        let wave = height * density * 0.55

        return Path { path in
            path.move(to: CGPoint(x: 0, y: base))
            path.addCurve(
                to: CGPoint(x: width * 0.5, y: base + wave * 0.3),
                control1: CGPoint(x: width * 0.18, y: base - wave),
                control2: CGPoint(x: width * 0.35, y: base - wave * 0.8)
            )
            path.addCurve(
                to: CGPoint(x: width, y: base - wave * 0.4),
                control1: CGPoint(x: width * 0.65, y: base + wave * 1.4),
                control2: CGPoint(x: width * 0.85, y: base - wave)
            )
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
        }
    }
}
