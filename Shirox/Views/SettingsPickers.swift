import SwiftUI

#if os(iOS) && !targetEnvironment(macCatalyst)

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
                // Typed literals: the bare `offset * -150` and `1 - abs(offset) * 2` read
                // ambiguous to Xcode 26.3's checker (a nightly failure); the intent is
                // unchanged.
                Text(options[index].title)
                    .font(.title2.bold())
                    .offset(x: offset * CGFloat(-150))
                    .opacity(Double(CGFloat(1) - min(abs(offset) * CGFloat(2), CGFloat(1))))
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
