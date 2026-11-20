import SwiftUI

/// First-run setup.
///
/// The design premise: Shirox ships with no content of its own, so a new user's real problem
/// isn't "what is this app" — it's "why is every screen empty". Onboarding therefore isn't a
/// carousel of feature slides; it's a checklist of the two things that actually make the app
/// work, wired to the real flows and reflecting real state. Rows tick themselves as soon as a
/// source or an account exists, so the screen always describes the app as it currently is.
///
/// The mark carries that idea: the app's 白 sits in an empty poster frame — dashed and grey
/// while nothing is connected, solid and tinted once a source is in place. The app is a frame
/// the user fills, and the frame says so.
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

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                // A plain page switch, not a paging TabView: the page style has no Mac or
                // Apple TV equivalent, and this way the dots and buttons are the same everywhere.
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

    // MARK: - Chrome

    /// Back when there's a page behind, Skip until the checklist.
    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { page -= 1 }
                } label: {
                    IconView("chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("onboarding.back")
            }
            Spacer()
            if page < lastPage {
                Button("onboarding.skip", action: finish)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    /// The dots and the next button; the checklist page carries its own call to action.
    private var controls: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0...lastPage, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? accent : Color.secondary.opacity(0.35))
                        .frame(width: index == page ? 18 : 7, height: 7)
                }
            }
            Spacer()
            if page < lastPage {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                } label: {
                    Text("onboarding.next")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Pages

    /// The app in one poster frame: the mark, the promise, and what it doesn't host.
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            frame
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

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
            .frame(maxWidth: 560)
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 24)
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
                    .foregroundStyle(.secondary)

                Text("onboarding.bring_your_own_nlibrary")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    stepRow(
                        title: String(localized: "onboarding.add_a_source"),
                        detail: hasSource
                            ? "\(moduleManager.modules.count) connected"
                            : String(localized: "onboarding.a_module_a_jellyfin_server"),
                        isDone: hasSource,
                        isRequired: true
                    ) { showSources = true }
                    .zoomSource("sources", in: sourcesZoom, cornerRadius: 14)

                    stepRow(
                        title: String(localized: "onboarding.sign_in_to_a_tracker"),
                        detail: trackerDetail,
                        isDone: hasTracker,
                        isRequired: false,
                        action: { showTracker = true }
                    )
                    .zoomSource("tracker", in: sourcesZoom, cornerRadius: 14)
                }
                .padding(.top, 24)

                Button(action: finish) {
                    Text(hasSource ? String(localized: "onboarding.start_watching") : String(localized: "onboarding.skip_for_now"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasSource ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                        )
                        .foregroundStyle(hasSource ? .white : Color.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 24)

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
    /// filled once one does. The same 2:3 as every poster elsewhere in the app.
    private var frame: some View {
        ZStack {
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
        }
        .frame(width: 116, height: 174)
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
                        .frame(width: 26, height: 26)
                    if isDone {
                        IconView("checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
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
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.09))
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isDone)
    }

    // MARK: - Actions

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

/// One page of the tour: an icon in a tinted tile, a headline, and a paragraph. All words,
/// no fake screenshots — the app's real screens are a page-turn away.
private struct TourPage: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let accent: Color

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 32)
            IconView(icon)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 108, height: 108)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(accent.opacity(0.12))
                )
            Text(title)
                .font(.system(size: 27, weight: .heavy))
                .multilineTextAlignment(.center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 32)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 560)
    }
}
