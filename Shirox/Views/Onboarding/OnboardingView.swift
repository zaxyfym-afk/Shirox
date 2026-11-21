import SwiftUI

/// First-run setup, redesigned around the Kavsoft pieces the project carries: the splash's
/// own reveal hands this screen the stage, the TWTextEffect engine types the welcome page's
/// promise, the AMSheets zoom transitions open the two setup sheets out of their rows, and
/// the glass chrome the toasts use dresses the cards on iOS 26.
///
/// The flow is three screens, each one a thing to do: the welcome, the appearance pick, and
/// the setup checklist. No tour pages between them — the app itself is the explanation, and
/// the checklist ticks from real state, so the last page always describes the app as it
/// currently is. The appearance pick applies the moment a card is tapped and persists like
/// any other setting.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppColorScheme.key) private var colorScheme = AppColorScheme.system.rawValue

    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var showSources = false
    /// The step the sources screen grows out of.
    @Namespace private var sourcesZoom
    @State private var showTracker = false
    /// The page being shown: welcome, appearance, then the setup checklist.
    @State private var page = 0
    private let lastPage = 2
    /// Which way the last page turn went, so the arriving page enters from that side.
    @State private var turnDirection: Edge = .trailing
    /// The hero's slow float, running only where motion is allowed.
    @State private var markFloats = false

    /// The one thing that has to be true before the app can show anything.
    private var hasSource: Bool { !moduleManager.modules.isEmpty }
    private var hasTracker: Bool { aniListAuth.isLoggedIn || malAuth.isLoggedIn }

    /// The project's own red, from its release badge — the welcome and setup pages' colour.
    private var accent: Color { Color(red: 0.937, green: 0.267, blue: 0.267) }

    /// Each page its own colour, so the flow reads as rooms rather than one white wall.
    private var pageAccent: Color {
        switch page {
        case 0: return accent
        case 1: return .indigo
        default: return accent
        }
    }

    private var motion: Animation? {
        reduceMotion ? nil : Animation.spring(response: 0.5, dampingFraction: 0.85)
    }

    var body: some View {
        ZStack {
            aurora

            VStack(spacing: 0) {
                topBar

                Group {
                    switch page {
                    case 0: welcomePage
                    case 1: appearancePage
                    default: setupPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(pageTurn)
                .id(page)
                .animation(motion, value: page)

                controls
            }
        }
        .background(platformBackground.ignoresSafeArea())
        .sheet(isPresented: $showSources) {
            // The real sources screen, not a copy of it: whatever it gains later, onboarding
            // gains too, and there's one code path to keep correct.
            NavigationStack {
                ModuleListView(showsDone: true)
            }
            .environmentObject(moduleManager)
            .macSheetFrame()
            .zoomingOut(of: "sources", in: sourcesZoom)
        }
        .sheet(isPresented: $showTracker) {
            // Both services with their own logos, rather than a button that only ever
            // offered one of them while the copy promised two.
            NavigationStack {
                TrackerSignInView()
            }
            .macSheetFrame()
            .zoomingOut(of: "tracker", in: sourcesZoom)
        }
    }

    /// The page's room: two blurred pools of the page's colour drifting slowly over the
    /// system background. The wash shifts colour with the page, so a turn reads as moving
    /// somewhere rather than swapping text.
    private var aurora: some View {
        ZStack {
            platformBackground

            Circle()
                .fill(pageAccent.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: markFloats ? -90 : 90, y: markFloats ? -160 : -60)
                .animation(reduceMotion ? nil : .easeInOut(duration: 5.5).repeatForever(autoreverses: true),
                           value: markFloats)

            Circle()
                .fill(pageAccent.opacity(0.13))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: markFloats ? 120 : -110, y: markFloats ? 210 : 130)
                .animation(reduceMotion ? nil : .easeInOut(duration: 6.5).repeatForever(autoreverses: true),
                           value: markFloats)
        }
        .animation(motion, value: page)
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            markFloats = true
        }
        .accessibilityHidden(true)
    }

    /// Pages carry themselves in from the direction the turn went — a little scale on the
    /// way in, a little blur — and leave by the other side.
    private var pageTurn: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: turnDirection)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .center)),
            removal: .move(edge: turnDirection == .trailing ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .center))
        )
    }

    // MARK: - Chrome

    /// Back when there's a page behind, Skip until the checklist.
    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    goBack()
                } label: {
                    IconView("chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                        .contentShape(Circle())
                }
                .buttonStyle(OnboardingPressStyle())
                .accessibilityLabel("onboarding.back")
            }
            Spacer()
            if page < lastPage {
                Button("onboarding.skip", action: finish)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }
        }
        .buttonStyle(OnboardingPressStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// The mark-shaped progress and the next button; the checklist page carries its own
    /// call to action. The progress grows a rounded tail on the page it's on rather than
    /// lighting a row of separate dots.
    private var controls: some View {
        HStack(spacing: 16) {
            OnboardingProgress(page: page, lastPage: lastPage, accent: pageAccent)

            Spacer()

            if page < lastPage {
                Button {
                    goForward()
                } label: {
                    HStack(spacing: 7) {
                        Text("onboarding.next")
                        IconView("chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [pageAccent, pageAccent.opacity(0.75)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: pageAccent.opacity(0.4), radius: 10, y: 4)
                }
                .buttonStyle(OnboardingPressStyle())
                .accessibilityHint("onboarding.next")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func goForward() {
        turnDirection = .trailing
        withAnimation(motion) { page += 1 }
    }

    private func goBack() {
        turnDirection = .leading
        withAnimation(motion) { page -= 1 }
    }

    // MARK: - Pages

    /// The app in one poster frame: the floating mark over the accent pool, the typed
    /// promise, and what the app doesn't host.
    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                frame
                    .padding(.top, 12)
                    .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text("onboarding.set_up_shirox")
                        .font(.caption.weight(.semibold))
                        .tracking(2.2)
                        .foregroundStyle(accent)

                    #if os(iOS)
                    // The promise, typed out one phrase at a time above the headline that says
                    // it in full. Below iOS 18, and on a Mac and Apple TV, the headline carries
                    // the page alone.
                    if #available(iOS 18.0, *) {
                        TypeWriterHeadline(
                            config: TypeWriterConfig(font: .system(size: 21, weight: .bold, design: .rounded)),
                            phrases: [
                                String(localized: "onboarding.type_watch"),
                                String(localized: "onboarding.type_read"),
                                String(localized: "onboarding.type_track")
                            ]
                        )
                        .foregroundStyle(pageAccent)
                        .padding(.top, 6)
                    }
                    #endif

                    Text("onboarding.bring_your_own_nlibrary")
                        .font(.system(size: 36, weight: .heavy))
                        .lineSpacing(-2)
                        .padding(.top, 8)

                    Text("onboarding.shirox_doesnt_host_any_content")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 560, alignment: .leading)
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Appearance

    /// Light, Dark or System, as three big cards that preview themselves: each one drawn
    /// the way its scheme looks. The pick applies the moment it's tapped and lands in the
    /// same store every other appearance control writes, so Settings can change it later.
    private var appearancePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(accent)

                Text("onboarding.appearance_title")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                Text("onboarding.appearance_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    appearanceCard(.light)
                    appearanceCard(.dark)
                    appearanceCard(.system)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    /// One appearance card: the scheme's own symbol on a tile, its name, and — behind it —
    /// a miniature of how the app draws in that scheme. Selected carries the accent ring
    /// and checkmark; tapping applies the scheme at once.
    private func appearanceCard(_ scheme: AppColorScheme) -> some View {
        let isSelected = colorScheme == scheme.rawValue
        return Button {
            guard colorScheme != scheme.rawValue else { return }
            colorScheme = scheme.rawValue
            AppColorScheme.apply()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            HStack(spacing: 14) {
                IconView(scheme.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(scheme == .dark ? Color.black : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .environment(\.colorScheme, scheme == .system ? .light : scheme.environmentScheme)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scheme.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(scheme.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isSelected {
                    IconView("checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(OnboardingPressStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Setup

    /// The checklist the flow ends on: the two things that make the app work, and the start
    /// button. Rows tick themselves from real state, so this page always describes the app
    /// as it currently is.
    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(accent)

                Text("onboarding.bring_your_own_nlibrary")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    stepRow(
                        title: String(localized: "onboarding.add_a_source"),
                        detail: hasSource
                            ? "\(moduleManager.modules.count) connected"
                            : String(localized: "onboarding.a_module_a_jellyfin_server"),
                        isDone: hasSource,
                        isRequired: true
                    ) { showSources = true }
                    .zoomSource("sources", in: sourcesZoom, cornerRadius: 16)

                    stepRow(
                        title: String(localized: "onboarding.sign_in_to_a_tracker"),
                        detail: trackerDetail,
                        isDone: hasTracker,
                        isRequired: false,
                        action: { showTracker = true }
                    )
                    .zoomSource("tracker", in: sourcesZoom, cornerRadius: 16)
                }
                .padding(.top, 24)

                Button(action: finish) {
                    Text(hasSource ? String(localized: "onboarding.start_watching") : String(localized: "onboarding.skip_for_now"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    hasSource
                                        ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.75)],
                                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Color.secondary.opacity(0.15))
                                )
                        )
                        .foregroundStyle(hasSource ? .white : Color.primary)
                        .shadow(color: hasSource ? accent.opacity(0.35) : .clear, radius: 12, y: 5)
                }
                .buttonStyle(OnboardingPressStyle())
                .padding(.top, 28)

                Text("onboarding.you_can_change_any_of")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
        }
    }

    private var trackerDetail: String {
        if aniListAuth.isLoggedIn && malAuth.isLoggedIn { return String(localized: "onboarding.anilist_and_myanimelist") }
        if aniListAuth.isLoggedIn { return "AniList" }
        if malAuth.isLoggedIn { return "MyAnimeList" }
        return String(localized: "onboarding.sync_your_progress_to_anilist")
    }

    // MARK: - The frame

    /// A poster-shaped outline holding the app's mark: empty and dashed until a source exists,
    /// filled once one does. The same 2:3 as every poster elsewhere in the app, floating
    /// slowly over the accent pool while the page shows.
    private var frame: some View {
        ZStack {
            // The wash: the accent blurred into the poster's neighbourhood, so the hero
            // reads as lit rather than drawn.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(accent.opacity(0.14))
                .blur(radius: 24)
                .padding(-14)
                .opacity(markFloats ? 0.95 : 0.6)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    hasSource ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 2, dash: hasSource ? [] : [7, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(hasSource ? accent.opacity(0.10) : Color.clear)
                )

            // The app's own mark, not the 白 typeface glyph — the logo has squared terminals
            // and its own angled top stroke, and a system font can't stand in for it. Shipped
            // as a template image so it takes the same grey/accent treatment as the frame.
            Image("ShiroMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 86)
                .foregroundStyle(hasSource ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary.opacity(0.35)))
                .offset(y: markFloats ? -8 : 8)
        }
        .frame(width: 128, height: 192)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: markFloats)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: hasSource)
        .accessibilityHidden(true)
    }

    // MARK: - Steps

    @ViewBuilder
    private func stepRow(
        title: String,
        detail: String,
        isDone: Bool,
        isRequired: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isDone ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1.5)
                        .background(Circle().fill(isDone ? accent : Color.clear))
                        .frame(width: 28, height: 28)
                    if isDone {
                        IconView("checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !isRequired && !isDone {
                            Text("settings.optional")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                IconView("chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isDone ? accent.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(OnboardingPressStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: isDone)
    }

    // MARK: - Actions

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }

    private var platformBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(tvOS)
        Color.clear
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
}

extension AppColorScheme {
    /// How a card previews the scheme behind its own content: System previews as light here,
    /// where the card itself already sits on either side of the system.
    var environmentScheme: ColorScheme {
        switch self {
        case .light, .system: return .light
        case .dark: return .dark
        }
    }

    /// One line under the scheme's name, saying what it does.
    var blurb: String {
        switch self {
        case .light:  return String(localized: "onboarding.appearance_light_blurb")
        case .dark:   return String(localized: "onboarding.appearance_dark_blurb")
        case .system: return String(localized: "onboarding.appearance_system_blurb")
        }
    }
}

/// A button that leans into the touch: a small spring press, the app's standard onboarding
/// feedback, on every control this screen has.
private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The onboarding's progress: one capsule that stretches to show where the read is, with
/// the passed pages behind it — a mark-shaped line rather than a row of dots.
private struct OnboardingProgress: View {
    let page: Int
    let lastPage: Int
    let accent: Color

    private let dotSize: CGFloat = 7
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? accent : Color.secondary.opacity(0.30))
                    .frame(width: index == page ? 20 : dotSize, height: dotSize)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.page_of \(page + 1) \(lastPage + 1)"))
    }
}
