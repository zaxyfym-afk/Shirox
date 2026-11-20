import SwiftUI

#if os(iOS) && !targetEnvironment(macCatalyst)

// MARK: - Theme picker

/// Light, dark or following the system, picked on a scene: the sun and moon trade places
/// over the hills as the choice changes, and the caption under says what each does.
/// Ported from the reference project's ATPicker; what it writes is the same
/// `AppColorScheme` the plain picker does.
@available(iOS 26.0, *)
struct ThemePickerSheet: View {
    @Binding var colorScheme: String
    @Environment(\.colorScheme) private var environmentScheme
    @State private var isDark: Bool

    init(colorScheme: Binding<String>, initialDark: Bool) {
        self._colorScheme = colorScheme
        _isDark = State(initialValue: initialDark)
    }

    private var scheme: AppColorScheme {
        AppColorScheme(rawValue: colorScheme) ?? .system
    }

    var body: some View {
        VStack(spacing: 15) {
            scene
                .frame(height: 200)

            segmentedControl

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .animation(.smooth(duration: 0.45), value: scheme)
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationBackground(isDark ? Color.black.mix(with: .white, by: 0.2) : .white)
        .presentationDetents([.height(300)])
        .presentationCompactAdaptation(.sheet)
        .sensoryFeedback(.selection, trigger: scheme)
        // The scene follows the environment, not the choice: it shows what IS, and the
        // choice is what will be.
        .onChange(of: environmentScheme) { _, newScheme in
            let dark = newScheme == .dark
            DispatchQueue.main.async {
                withAnimation(.interpolatingSpring(duration: 1, bounce: 0)) {
                    isDark = dark
                }
            }
        }
    }

    private var caption: String {
        switch scheme {
        case .light:  return String(localized: "settings.theme_light_caption")
        case .dark:   return String(localized: "settings.theme_dark_caption")
        case .system: return String(localized: "settings.theme_system_caption")
        }
    }

    // MARK: The scene

    private var scene: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gradient = isDark ? [Color.skyTopDark, Color.skyBottomDark] : [Color.skyTopLight, Color.skyBottomLight]

            ZStack {
                LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)

                StarsView(count: 15)
                    .opacity(isDark ? 1 : 0)

                // The sun and the moon, trading places around the sky.
                ZStack {
                    IconView("moon.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.moonlight)
                        .shadow(color: Color.moonlight.opacity(0.6), radius: 15)
                        .rotationEffect(.degrees(isDark ? -130 : 0))
                        .frame(width: size.width, height: size.width)
                        .offset(x: -(size.width - 40) / 2)
                        .rotationEffect(.degrees(isDark ? 130 : -30))
                        .offset(y: 10)

                    IconView("sun.max.fill")
                        .font(.system(size: 85, weight: .ultraLight))
                        .foregroundStyle(.yellow)
                        .shadow(color: .white, radius: 15)
                        // Spinning continuously, unhurried.
                        .compositingGroup()
                        .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { content, rotation in
                            content.rotationEffect(.degrees(rotation))
                        } keyframes: { _ in
                            LinearKeyframe(360, duration: 60)
                        }
                        .frame(width: size.width, height: size.width)
                        .offset(x: -(size.width - 40) / 2)
                        .rotationEffect(.degrees(isDark ? 200 : 130))
                        .offset(y: 10)
                }
                .frame(width: size.width, height: size.height, alignment: .top)

                // A shooting star, dark mode's own.
                if isDark {
                    KeyframeAnimator(initialValue: CGFloat.zero, repeating: true) { offset in
                        let opacity = max(min(offset / 200, 1), 0)
                        Capsule()
                            .fill(LinearGradient(colors: [
                                Color.moonlight,
                                Color.moonlight.opacity(0.5),
                                Color.moonlight.opacity(0.3),
                                Color.moonlight.opacity(0.3),
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

                // Clouds, blowing away as the night comes.
                HStack(spacing: 0) {
                    IconView("cloud.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? -100 : 0, y: -30)

                    Spacer(minLength: 0)

                    IconView("cloud.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? 100 : 0)

                    Spacer(minLength: 0)

                    IconView("cloud.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .offset(x: isDark ? 100 : 0, y: 35)
                }
                .padding(.horizontal, 20)
                .compositingGroup()
                .blur(radius: isDark ? 30 : 0)
                .opacity(isDark ? 0 : 1)

                // The hills, and the house with its lamp lit at night.
                ZStack {
                    HillShape(density: 0.5)
                        .fill(isDark ? Color.hillTopDark : Color.hillTopLight)
                    HillShape(density: 0.35)
                        .fill(isDark ? Color.hillCenterDark : Color.hillCenterLight)
                    HillShape(density: 0.2)
                        .fill(isDark ? Color.hillBottomDark : Color.hillBottomLight)

                    IconView("house.lodge.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.black.mix(with: .white, by: isDark ? 0.1 : 0.4))
                        .background(alignment: .bottom) {
                            Circle()
                                .fill(.yellow.opacity(isDark ? 1 : 0))
                                .frame(width: 12, height: 12)
                                .shadow(color: .yellow.opacity(isDark ? 1 : 0), radius: 5)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .offset(x: 50, y: -44)
                }
                .frame(height: 100)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipShape(ConcentricRectangle(corners: .concentric, isUniform: true))
    }

    // MARK: The segmented control

    private var segmentedControl: some View {
        @Namespace private var capsule
        return HStack(spacing: 0) {
            ForEach([AppColorScheme.light, .dark, .system], id: \.rawValue) { option in
                let isSelected = scheme == option
                let tint: Color = isDark ? .indigo : .yellow.mix(with: .orange, by: 0.2)
                let rotation: CGFloat = option == .light ? 180 : option == .dark ? -15 : (isDark ? 180 : 0)

                HStack(spacing: 8) {
                    IconView(option.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? tint : (isDark ? .white : .black))
                        .environment(\.colorScheme, .light)
                        .rotationEffect(.degrees(isSelected ? rotation : 0))

                    Text(option.title)
                        .font(.callout)
                        .foregroundStyle(isDark ? .white : .black)
                        .environment(\.colorScheme, .light)
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        ZStack {
                            Capsule().fill(isDark ? .black : .white)
                            Capsule().stroke(tint, lineWidth: 1.5).padding(0.5)
                        }
                        .compositingGroup()
                        .shadow(color: tint.opacity(0.3), radius: 10)
                        .matchedGeometryEffect(id: "CAPSULE", in: capsule)
                    }
                }
                .onTapGesture { colorScheme = option.rawValue }
            }
        }
        .frame(height: 40)
        .padding(4)
        .background(.gray.opacity(0.15), in: .capsule)
        .animation(.bouncy(duration: 0.5, extraBounce: 0.1), value: scheme)
    }
}

/// The scene's own colours, apart from the app's.
private extension Color {
    static let skyTopDark = Color(red: 0.09, green: 0.11, blue: 0.24)
    static let skyBottomDark = Color(red: 0.25, green: 0.22, blue: 0.45)
    static let skyTopLight = Color(red: 0.55, green: 0.78, blue: 0.97)
    static let skyBottomLight = Color(red: 0.85, green: 0.93, blue: 0.99)
    static let moonlight = Color(red: 0.98, green: 0.96, blue: 0.88)
    static let hillTopDark = Color(red: 0.13, green: 0.15, blue: 0.28)
    static let hillCenterDark = Color(red: 0.19, green: 0.20, blue: 0.35)
    static let hillBottomDark = Color(red: 0.25, green: 0.25, blue: 0.42)
    static let hillTopLight = Color(red: 0.42, green: 0.70, blue: 0.42)
    static let hillCenterLight = Color(red: 0.53, green: 0.78, blue: 0.51)
    static let hillBottomLight = Color(red: 0.65, green: 0.85, blue: 0.60)
}

/// The night's stars, each in a deterministic place: the same sky every time.
private struct StarsView: View {
    var count: Int

    var body: some View {
        Canvas { context, size in
            for i in 0..<count {
                let x = Self.random(i, 1) * size.width
                let y = Self.random(i, 2) * size.height
                let starSize = Self.random(i, 3) > 0.66 ? 3.0 : 2.0
                let opacity = 0.5 + Self.random(i, 4) * 0.5
                let star = Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize))
                context.fill(star, with: .color(.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    private static func random(_ i: Int, _ seed: Double) -> Double {
        let value = sin(Double(i) * 22.5 + seed * 99.2) * 43.6
        return value - value.rounded(.down)
    }
}

/// The rolling hills the house sits on.
private struct HillShape: Shape {
    var density: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let base = height * (1 - density)
        let wave = height * density * 0.55

        var path = Path()
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
        return path
    }
}

// MARK: - App icon picker

/// The home screen icons as a carousel: the chosen one centred and square, the rest
/// falling away scaled and blurred, the count and name above and below. Ported from the
/// reference project's AIPicker; what it sets is the same alternate icon the plain
/// picker does.
@available(iOS 26.0, *)
struct AppIconPickerSheet: View {
    @State private var active: AppIconOption?
    @State private var scrollOffset: CGFloat = 0
    @State private var iconError: String?
    @Environment(\.dismiss) private var dismiss

    private var options: [AppIconOption] { AppIconOption.all }
    private var current: AppIconOption {
        options.first { $0.name == UIApplication.shared.alternateIconName } ?? AppIconOption(name: nil)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let iconSize = size.height * 0.5

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(options) { option in
                        iconTile(option, size: iconSize)
                            .id(option.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $active)
            .safeAreaPadding(.horizontal, (size.width - iconSize) / 2)
            .overlay(alignment: .top) {
                counter
            }
            .overlay(alignment: .bottom) {
                nameLabel(step: iconSize)
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.x + $0.contentInsets.leading
            } action: { _, newValue in
                scrollOffset = newValue
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .overlay(alignment: .topLeading) {
            Button(role: .close) {
                dismiss()
            } label: {
                IconView("xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
        }
        .safeAreaPadding(15)
        .ignoresSafeArea(.all, edges: .bottom)
        .presentationDetents([.height(400)])
        .presentationCompactAdaptation(.sheet)
        .sensoryFeedback(.selection, trigger: active)
        .onAppear {
            if active == nil { active = current }
        }
        .alert("settings.couldnt_change_icon",
               isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(iconError ?? "")
        }
    }

    // MARK: The carousel

    private func iconTile(_ option: AppIconOption, size: CGFloat) -> some View {
        ZStack {
            switch option.name {
            case nil:
                Image("ShiroMark")
                    .resizable().scaledToFit()
                    .padding(10)
                    .frame(width: size, height: size)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            case "realistic":
                Image("AppIconRealistic")
                    .resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            case let name?:
                // An icon with no preview of its own: its initial, as the store's entries do.
                Text(String(option.title.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.accentColor.opacity(0.75), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }
        }
        .visualEffect { content, proxy in
            let minX = proxy.frame(in: .scrollView).minX
            let progress = min(abs(minX / size), 1)
            return content
                .scaleEffect(1 - (progress * 0.3))
                .blur(radius: progress * 4)
                .offset(x: minX / 2)
                .rotationEffect(.degrees(progress * -(size / 2)))
        }
    }

    private var counter: some View {
        let index = options.firstIndex { $0.id == active?.id } ?? 0
        return HStack(alignment: .bottom, spacing: 2) {
            Text(String(format: "%02d", index + 1))
                .font(.title3.bold())
                .foregroundStyle(.tint)
                .contentTransition(.numericText(value: Double(index)))
            Group {
                Text("/")
                Text(String(format: "%02d", options.count))
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        }
        .monospaced()
        .animation(.easeInOut(duration: 0.25), value: active)
        .offset(y: 3)
    }

    /// Each option's name, sliding with the carousel: the one centred reads plainly.
    private func nameLabel(step iconSize: CGFloat) -> some View {
        let progress = scrollOffset / max(iconSize, 1)
        return ZStack {
            ForEach(options.indices, id: \.self) { index in
                let offset = progress - CGFloat(index)
                Text(options[index].title)
                    .font(.title2.bold())
                    .offset(x: offset * -150)
                    .opacity(1 - min(abs(offset) * 2, 1))
            }
        }
        .offset(y: -25)
        .allowsHitTesting(false)
    }

    // MARK: The bottom bar

    private var bottomBar: some View {
        let isActive = active?.id == current.id
        return VStack(spacing: 15) {
            Text("settings.icon_picker_hint")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                guard UIApplication.shared.supportsAlternateIcons else {
                    iconError = String(localized: "settings.this_device_doesnt_support_changing")
                    return
                }
                UIApplication.shared.setAlternateIconName(active?.name) { error in
                    DispatchQueue.main.async {
                        if let error {
                            iconError = error.localizedDescription
                        } else {
                            dismiss()
                        }
                    }
                }
            } label: {
                Text(isActive ? String(localized: "settings.currently_active") : String(localized: "settings.activate_app_icon"))
                    .contentTransition(.numericText())
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .disabled(isActive)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .padding(.bottom, 10)
            .padding(.top, 5)
        }
        .padding(.horizontal, 15)
    }
}

#endif
