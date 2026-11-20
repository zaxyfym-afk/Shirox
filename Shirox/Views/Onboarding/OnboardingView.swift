import SwiftUI

/// First-run setup, redesigned.
///
/// The design premise is unchanged — Shirox ships with no content of its own, so a new
/// user's real problem isn't "what is this app", it's "why is every screen empty". The
/// presentation around that premise is new: a hero mark that floats over a soft accent
/// wash, pages that carry themselves in from the direction they're read, a mark-shaped
/// progress that grows instead of a row of dots, and a checklist whose rows tick with a
/// spring the moment a source or an account exists, so the screen always describes the
/// app as it currently is.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var showSources = false
    /// The step the sources screen grows out of.
    @Namespace private var sourcesZoom
    @State private var showTracker = false
    /// The page being shown: a tour of what the app does, then the setup checklist it ends on.
    @State private var page = 0
    private let lastPage = 6
    /// Which way the last page turn went, so the arriving page enters from that side.
    @State private var turnDirection: Edge = .trailing
    /// The welcome mark's slow float, running only where motion is allowed.
    @State private var markFloats = false

    /// The one thing that has to be true before the app can show anything.
    private var hasSource: Bool { !moduleManager.modules.isEmpty }
    private var hasTracker: Bool { aniListAuth.isLoggedIn || malAuth.isLoggedIn }

    /// The project's own red, from its release badge — the one accent this screen spends.
    private var accent: Color { Color(red: 0.937, green: 0.267, blue: 0.267) }

    private var platformBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #elseif os(tvOS)
        Color.clear
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    private var motion: Animation? {
        reduceMotion ? nil : Animation.spring(response: 0.5, dampingFraction: 0.85)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                switch page {
                case 0: welcomePage
                case 1: TourPage(icon: "books.vertical", title: "onboarding.tour_library_title", text: "onboarding.tour_library_body", accent: accent)
                case 2: TourPage(icon: "puzzlepiece.extension", title: "onboarding.tour_modules_title", text: "onboarding.tour_modules_body", accent: accent)
                case 3: TourPage(icon: "arrow.down.circle", title: "onboarding.tour_downloads_title", text: "onboarding.tour_downloads_body", accent: accent)
                case 4: TourPage(icon: "bell", title: "onboarding.tour_notifications_title", text: "onboarding.tour_notifications_body", accent: accent)
                case 5: TourPage(icon: "paintpalette", title: "onboarding.tour_customize_title", text: "onboarding.tour_customize_body", accent: accent)
                default: setupPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(pageTurn)
            .id(page)
            .animation(motion, value: page)

            controls
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

    /// Pages carry themselves in from the direction the turn went, with a little blur on
    /// the way, and leave by the other side.
    private var pageTurn: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: turnDirection)
                .combined(with: .opacity)
                .combined(with: .offset(y: 12)),
            removal: .move(edge: turnDirection == .trailing ? .leading : .trailing)
                .combined(with: .opacity)
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
                        .background(Color.secondary.opacity(0.1), in: Circle())
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
                    .background(Color.secondary.opacity(0.1), in: Capsule())
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
            OnboardingProgress(page: page, lastPage: lastPage, accent: accent)

            Spacer()

            if page < lastPage {
                Button {
                    goForward()
                } label: {
                    HStack(spacing: 7) {
                        Text(LocalizedStringKey(page == 0 ? "onboarding.tour" : "onboarding.next"))
                        IconView("chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(accent))
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

    /// The app in one poster frame: the floating mark over a soft accent wash, the typed
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
                        TypeWriterHeadline(phrases: [
                            String(localized: "onboarding.type_watch"),
                            String(localized: "onboarding.type_read"),
                            String(localized: "onboarding.type_track")
                        ])
                        .foregroundStyle(.secondary)
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
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                markFloats = true
            }
        }
    }

    /// The checklist the tour ends on: the two things that make the app work, and the start
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
                                .fill(hasSource ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                        )
                        .foregroundStyle(hasSource ? .white : Color.primary)
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
    /// filled once one does. The same 2:3 as every poster elsewhere in the app, over a soft
    /// wash of the accent, and floating slowly while the page shows.
    private var frame: some View {
        ZStack {
            // The wash: the accent blurred into the poster's neighbourhood, so the hero
            // reads as lit rather than drawn.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(accent.opacity(0.12))
                .blur(radius: 24)
                .padding(-14)
                .opacity(markFloats ? 0.9 : 0.65)

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
                .offset(y: markFloats ? -7 : 7)
        }
        .frame(width: 128, height: 192)
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
                    .fill(Color.secondary.opacity(0.09))
            )
        }
        .buttonStyle(OnboardingPressStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: isDone)
    }

    // MARK: - Actions

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
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

/// One page of the tour: an icon in a tinted tile that arrives with a small overshoot, a
/// headline, and a paragraph. All words, no fake screenshots — the app's real screens are
/// a page-turn away.
private struct TourPage: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let accent: Color

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                IconView(icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 108, height: 108)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                    )
                    .scaleEffect(shown ? 1 : 0.7)
                    .opacity(shown ? 1 : 0)
                Text(title)
                    .font(.system(size: 27, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 560)
        }
        .onAppear {
            guard !reduceMotion, !shown else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { shown = true }
        }
        .onDisappear { shown = false }
    }
}
