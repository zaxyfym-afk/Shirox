import AuthenticationServices
import SwiftUI
import UserNotifications

/// First-run setup, rebuilt around the two Kavsoft pieces the project carries: the
/// appearance pick is the real ATPicker port — the animated sky, the sliding capsule, the
/// pick applying the instant it's tapped — and the notifications page is the
/// CompactNotificationView port, its keyframed notification stack standing in for a wall of
/// text. The rest is white and grey on purpose: nothing between the user and the two things
/// the app needs (a source, and whatever tracking they want).
///
/// The flow is four screens: the welcome, the appearance pick, connecting sources, then
/// notification permission. No informational pages between them, and one back control —
/// the system bar's arrow is hidden where this screen is pushed, so the custom chevron is
/// the only one there is.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppColorScheme.key) private var colorScheme = AppColorScheme.system.rawValue

    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @ObservedObject private var notifier = EpisodeReleaseNotifier.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var envColorScheme

    @State private var showSources = false
    /// The step the sources screen grows out of.
    @Namespace private var sourcesZoom
    /// The page being shown: welcome, appearance, connect, notifications.
    @State private var page = 0
    private let lastPage = 3
    /// Which way the last page turn went, so the arriving page enters from that side.
    @State private var turnDirection: Edge = .trailing
    /// The hero's slow float, running only where motion is allowed.
    @State private var markFloats = false
    #if os(iOS)
    @State private var presentationWindow: UIWindow?
    #endif
    /// The notifications page's state: permission read on entry, so a previously determined
    /// answer (granted in an earlier run, or refused) is honoured and the system prompt is
    /// never shown twice.
    @State private var permissionStatus: UNAuthorizationStatus?

    /// The one thing that has to be true before the app can show anything.
    private var hasSource: Bool { !moduleManager.modules.isEmpty }
    private var hasTracker: Bool { aniListAuth.isLoggedIn || malAuth.isLoggedIn }
    private var hasBothTrackers: Bool { aniListAuth.isLoggedIn && malAuth.isLoggedIn }

    private var motion: Animation? {
        reduceMotion ? nil : Animation.spring(response: 0.5, dampingFraction: 0.85)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar

                Group {
                    switch page {
                    case 0: welcomePage
                    case 1: appearancePage
                    case 2: connectPage
                    default: notificationsPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(pageTurn)
                .id(page)
                .animation(motion, value: page)

                controls
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .modifier(OnboardingNavBarHider())
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
        #if os(iOS)
        .onAppear {
            presentationWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        #endif
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

    /// Back when there's a page behind, Skip until the last page. The only back control on
    /// the flow: the system bar's arrow is hidden, so nothing doubles up when Settings
    /// replays this screen inside its own stack.
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
                        .background(Color.primary.opacity(0.06), in: Circle())
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
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }
        }
        .buttonStyle(OnboardingPressStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// The progress line and the next button; the last page carries its own call to action.
    private var controls: some View {
        HStack(spacing: 16) {
            OnboardingProgress(page: page, lastPage: lastPage)

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
                        Capsule().fill(Color.primary.opacity(0.85))
                    )
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

    // MARK: - Welcome

    /// The app in one poster frame: the floating mark, the typed promise, and what the app
    /// doesn't host. Grey ink on white; the colour lives in the mark itself.
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
                        .foregroundStyle(.secondary)

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
                        .foregroundStyle(.primary)
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

    // MARK: - Appearance

    /// The Kavsoft picker, inline: the animated sky that turns night when dark is chosen and
    /// day when light is, the capsule sliding under the scheme it's on. The pick applies to
    /// the whole app the moment it's tapped — the sky's own change is the app's change.
    private var appearancePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

                Text("onboarding.appearance_title")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                Text("onboarding.appearance_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                KavsoftThemePicker(
                    value: Binding(
                        get: { AppColorScheme(rawValue: colorScheme) ?? .system },
                        set: { colorScheme = $0.rawValue }
                    ),
                    envColorScheme: envColorScheme
                )
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    // MARK: - Connect

    /// The two things the app needs connected, each its own action: a source to play from,
    /// and whichever trackers the user keeps their lists on. AniList and MyAnimeList each
    /// get their own connect button and their own state; one of them is fine, both are
    /// better, and neither blocks the flow.
    private var connectPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

                Text("onboarding.connect_sources")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                Text("onboarding.sources_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    sourceRow
                        .zoomSource("sources", in: sourcesZoom, cornerRadius: 16)

                    trackerCard(.anilist)
                    trackerCard(.mal)

                    trackerRecommendation
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        #if os(iOS)
        .onAppear {
            if presentationWindow == nil {
                presentationWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }
            }
        }
        #endif
    }

    /// The source row: the one thing the app can't open without. Ticking comes from real
    /// state — the count of installed modules is the row's detail once one is in.
    private var sourceRow: some View {
        Button {
            showSources = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(hasSource ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1.5)
                        .background(Circle().fill(hasSource ? Color.primary.opacity(0.85) : Color.clear))
                        .frame(width: 28, height: 28)
                    if hasSource {
                        IconView("checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("onboarding.add_source")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(hasSource
                         ? "\(moduleManager.modules.count) connected"
                         : String(localized: "onboarding.add_source_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                IconView("chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(hasSource ? Color.primary.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(OnboardingPressStyle())
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: hasSource)
    }

    /// One tracker card: the service's own logo on its tile, its name, and its own connect
    /// button that becomes a signed-in line the moment the web session lands.
    private func trackerCard(_ type: ProviderType) -> some View {
        let isLoggedIn = type == .anilist ? aniListAuth.isLoggedIn : malAuth.isLoggedIn
        let username = type == .anilist ? aniListAuth.username : malAuth.username
        return HStack(spacing: 14) {
            CachedAsyncImage(urlString: type.iconURL)
                .frame(width: 44, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(type == .anilist
                     ? String(localized: "onboarding.anilist_blurb")
                     : String(localized: "onboarding.mal_blurb"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isLoggedIn {
                Label(username.map { "onboarding.signed_in_as \($0)" } ?? "settings.signed_in",
                      icon: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    signIn(type)
                } label: {
                    Text("library.sign_in")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(OnboardingPressStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: isLoggedIn)
    }

    /// One line under the cards: neither connected says what the choice is, one connected
    /// recommends the other, both connected confirms. Never a wall of text, never a block.
    @ViewBuilder
    private var trackerRecommendation: some View {
        if hasBothTrackers {
            Label("onboarding.all_connected", icon: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        } else if hasTracker {
            Label("onboarding.recommend_both", icon: "personalhotspot")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func signIn(_ type: ProviderType) {
        #if os(iOS)
        guard let presentationWindow else { return }
        if type == .anilist {
            aniListAuth.login(presentationAnchor: presentationWindow)
        } else {
            malAuth.login(presentationAnchor: presentationWindow)
        }
        #else
        let anchor: ASPresentationAnchor = ASPresentationAnchor()
        if type == .anilist {
            aniListAuth.login(presentationAnchor: anchor)
        } else {
            malAuth.login(presentationAnchor: anchor)
        }
        #endif
    }

    // MARK: - Notifications

    /// The Kavsoft notification permission experience, inline: the keyframed stack of
    /// episode alerts rising and dissolving over the bell, then one button that asks iOS
    /// for permission and one that moves on. A permission already decided (granted, or
    /// refused in an earlier run) is honoured — no system prompt re-appears, and the page
    /// says where things stand.
    private var notificationsPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch notificationState {
                case .undetermined:
                    KavsoftNotificationPermissionView(
                        primaryAction: {
                            Task {
                                _ = await notifier.requestPermissionIfNeeded()
                                permissionStatus = await notifier.authorizationStatus
                            }
                        },
                        secondaryAction: finish
                    )
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                case .granted:
                    permissionLine(key: "onboarding.notifications_on", symbol: "bell.badge.fill")
                case .denied:
                    permissionLine(key: "onboarding.notifications_off", symbol: "bell.slash")
                }

                Button {
                    finish()
                } label: {
                    Text(hasSource ? String(localized: "onboarding.start_watching")
                                   : String(localized: "onboarding.skip_for_now"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.85))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(OnboardingPressStyle())
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .task { permissionStatus = await notifier.authorizationStatus }
    }

    private enum NotificationAskState { case undetermined, granted, denied }

    private var notificationState: NotificationAskState {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        default: return .undetermined
        }
    }

    /// What the page says when iOS has already answered for this app: granted, or refused —
    /// with the way back through system settings for the second.
    private func permissionLine(key: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Label {
                Text(LocalizedStringKey(key))
            } icon: {
                IconView(symbol)
            }
            .font(.body.weight(.semibold))
            .padding(.vertical, 30)

            if notificationState == .denied {
                Button {
                    #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #elseif os(macOS)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                } label: {
                    Text("notifications.open_system_settings")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .buttonStyle(OnboardingPressStyle())
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - The frame

    /// A poster-shaped outline holding the app's mark: empty and dashed until a source exists,
    /// filled once one does. The same 2:3 as every poster elsewhere in the app, floating
    /// slowly while the page shows.
    private var frame: some View {
        ZStack {
            // The wash: neutral grey blurred into the poster's neighbourhood, so the hero
            // reads as lit rather than drawn.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .blur(radius: 24)
                .padding(-14)
                .opacity(markFloats ? 0.95 : 0.6)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    hasSource ? AnyShapeStyle(Color.primary.opacity(0.8)) : AnyShapeStyle(Color.secondary.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 2, dash: hasSource ? [] : [7, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(hasSource ? Color.primary.opacity(0.05) : Color.clear)
                )

            // The app's own mark, not the 白 typeface glyph — the logo has squared terminals
            // and its own angled top stroke, and a system font can't stand in for it. Shipped
            // as a template image so it takes the same grey treatment as the frame.
            Image("ShiroMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 86)
                .foregroundStyle(hasSource ? AnyShapeStyle(Color.primary.opacity(0.85)) : AnyShapeStyle(Color.secondary.opacity(0.35)))
                .offset(y: markFloats ? -8 : 8)
        }
        .frame(width: 128, height: 192)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: markFloats)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: hasSource)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

extension AppColorScheme {
    /// One line under the scheme's name, saying what it does.
    var blurb: String {
        switch self {
        case .light:  return String(localized: "onboarding.appearance_light_blurb")
        case .dark:   return String(localized: "onboarding.appearance_dark_blurb")
        case .system: return String(localized: "onboarding.appearance_system_blurb")
        }
    }
}

/// Hides the navigation bar on the pushed (Settings replay) path, iOS 16 style API on top
/// of the deprecated form below. This is what keeps the flow to one back control.
private struct OnboardingNavBarHider: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content.navigationBarHidden(true)
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

    private let dotSize: CGFloat = 7
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.30))
                    .frame(width: index == page ? 20 : dotSize, height: dotSize)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.page_of \(page + 1) \(lastPage + 1)"))
    }
}
