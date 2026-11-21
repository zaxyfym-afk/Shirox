import AuthenticationServices
import SwiftUI

/// First-run setup, rebuilt around the two Kavsoft pieces the project carries: the
/// appearance pick is the real ATPicker port — the animated sky, the sliding capsule, the
/// pick applying the instant it's tapped — and the welcome page opens out of the real
/// ASplashScreen port, the launch icon shrinking and rising to reveal the flow beneath.
/// The rest is white and grey on purpose: nothing between the user and the two things the
/// app needs (a source, and whatever tracking they want).
///
/// The flow is four screens: the welcome, the appearance pick, connecting the AniList and
/// MyAnimeList accounts, then modules. No informational pages between them, and one back
/// control — the system bar's arrow is hidden where this screen is pushed, so the custom
/// chevron is the only one there is. Pages also turn by swipe, and the turn itself guards
/// the buttons: a Next tapped while the previous transition is still moving does nothing,
/// so no amount of tapping or swiping can stack two copies of the last page.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppColorScheme.key) private var colorScheme = AppColorScheme.system.rawValue

    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @ObservedObject private var store = ModuleStoreService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var envColorScheme

    /// The page being shown: welcome, appearance, accounts, modules.
    @State private var page = 0
    private let lastPage = 3
    /// Which way the last page turn went, so the arriving page enters from that side.
    @State private var turnDirection: Edge = .trailing
    /// True from the moment a turn starts until its transition has finished: every
    /// navigation path checks it, so a rapid second tap or swipe is refused rather than
    /// stacked onto the moving page. This is the single source of truth for the step.
    @State private var isTurning = false
    /// The hero's slow float, running only where motion is allowed.
    @State private var markFloats = false

    // The modules page: the two catalogs' picks, the Store door, the import-by-link field.
    @State private var recommended: [ModuleStoreEntry] = []
    @State private var catalogLoaded = false
    @State private var installingEntryIDs: Set<String> = []
    @State private var showStore = false
    @State private var importURL = ""
    @State private var isImporting = false
    @State private var importError: String?

    #if os(iOS)
    @State private var presentationWindow: UIWindow?
    #endif

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
                    case 2: accountsPage
                    default: modulesPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(pageTurn)
                .id(page)
                .animation(motion, value: page)
                // The swipe: a horizontal drag that ends past the threshold turns the page.
                // Vertical scrolling and the pages' own controls never reach it — it only
                // fires when the drag was mostly sideways, and never mid-turn.
                .contentShape(Rectangle())
                .gesture(swipe)
            }

            controls
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .modifier(OnboardingNavBarHider())
        #if !os(tvOS)
        .sheet(isPresented: $showStore) {
            // The real store, over the modules page: whatever it gains later, onboarding
            // gains too, and it returns here the moment it's done.
            NavigationStack {
                ModuleStoreView()
            }
            .environmentObject(moduleManager)
            .macSheetFrame()
        }
        #endif
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

    /// The horizontal swipe: ends only, mostly horizontal, well past a short drag, and
    /// refused while a turn is already running. Clamping lives in `goBack`/`goForward`,
    /// so neither direction can leave the valid pages.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                guard !isTurning else { return }
                let horizontal = value.translation.width
                guard abs(horizontal) > 64,
                      abs(horizontal) > abs(value.translation.height) * 1.5 else { return }
                if horizontal < 0 {
                    goForward()
                } else {
                    goBack()
                }
            }
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
        guard page < lastPage, !isTurning else { return }
        turnDirection = .trailing
        page = min(page + 1, lastPage)
        holdTheGate()
    }

    private func goBack() {
        guard page > 0, !isTurning else { return }
        turnDirection = .leading
        page = max(page - 1, 0)
        holdTheGate()
    }

    /// Closes navigation for the length of the page's transition, then opens it again.
    /// With `page` clamped on both edges and the gate checked on every path — buttons,
    /// swipes, Skip — repeated rapid taps cannot push the same page twice or walk the
    /// count past either end.
    private func holdTheGate() {
        isTurning = true
        let settle: Double = reduceMotion ? 0.08 : 0.55
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
            isTurning = false
        }
    }

    // MARK: - The balanced page

    /// Every page's container: the content is centred in the space when it fits, scrolls
    /// when it doesn't, and never sits pinned to the top with dead space below.
    private struct BalancedPage<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        content()
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Welcome

    /// The app in one poster frame: the floating mark, the typed promise, and what the app
    /// doesn't host. Grey ink on white; the colour lives in the mark itself.
    private var welcomePage: some View {
        BalancedPage {
            VStack(alignment: .leading, spacing: 0) {
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
            }
        }
        .onAppear {
            markFloats = false
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { markFloats = true }
            }
        }
    }

    // MARK: - Appearance

    /// The Kavsoft picker, inline: the animated sky that turns night when dark is chosen and
    /// day when light is, the capsule sliding under the scheme it's on. The pick applies to
    /// the whole app the moment it's tapped — the sky's own change is the app's change.
    private var appearancePage: some View {
        BalancedPage {
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
        }
    }

    // MARK: - Accounts

    /// The two trackers the app writes back to, each its own card and its own connect
    /// button, with connected states that flip the moment the web session lands. One of
    /// them is fine, both are better, and neither blocks the flow.
    private var accountsPage: some View {
        BalancedPage {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

                Text("onboarding.connect_accounts")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                Text("onboarding.accounts_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    trackerCard(.anilist)
                    trackerCard(.mal)

                    trackerRecommendation
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
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

    // MARK: - Modules

    /// The three ways in, on one page: the catalogs' recommended picks with an install
    /// button each, the Store behind one clear door, and import-by-link for a module from
    /// anywhere. The finish button closes the flow; nothing here is required first.
    private var modulesPage: some View {
        BalancedPage {
            VStack(alignment: .leading, spacing: 0) {
                Text("onboarding.set_up_shirox")
                    .font(.caption.weight(.semibold))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)

                Text("onboarding.modules_title")
                    .font(.system(size: 30, weight: .heavy))
                    .lineSpacing(-2)
                    .padding(.top, 8)

                Text("onboarding.modules_body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    recommendedCard
                    storeDoor
                    importCard
                }
                .padding(.top, 20)
                .padding(.bottom, 24)

                finishButton
            }
        }
        .task { await loadRecommendations() }
    }

    /// The finish button the last page carries itself: it starts the app, modules or no
    /// modules — the Store is always there later.
    private var finishButton: some View {
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
        .padding(.top, 4)
    }

    /// The two catalogs' picks: entries flagged featured first, the rest filling behind
    /// them, only ones not installed already. Each row installs from its manifest; the
    /// button turns into its progress and then a checkmark.
    @ViewBuilder
    private var recommendedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("onboarding.recommended_modules")
                    .font(.body.weight(.semibold))
                if !catalogLoaded {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if catalogLoaded, recommended.isEmpty {
                Text("onboarding.recommended_empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(recommended) { entry in
                HStack(spacing: 12) {
                    ModuleStoreEntryIcon(entry: entry, size: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(entry.tagline)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    recommendedInstallButton(entry)
                }
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
    }

    @ViewBuilder
    private func recommendedInstallButton(_ entry: ModuleStoreEntry) -> some View {
        if store.installedModule(for: entry) != nil {
            IconView("checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityLabel(Text("modules.installed"))
        } else if installingEntryIDs.contains(entry.id) {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                install(entry)
            } label: {
                Text("modules.add")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(OnboardingPressStyle())
        }
    }

    private func install(_ entry: ModuleStoreEntry) {
        installingEntryIDs.insert(entry.id)
        Task {
            await store.install(entry)
            installingEntryIDs.remove(entry.id)
        }
    }

    private func loadRecommendations() async {
        guard !catalogLoaded else { return }
        await store.load()
        let installed = Set(moduleManager.modules.compactMap(\.sourceName))
        let featured = store.catalog.entries.filter { $0.featured == true }
        let rest = store.catalog.entries.filter { $0.featured != true }
        recommended = Array((featured + rest).filter { !installed.contains($0.name) }.prefix(5))
        catalogLoaded = true
    }

    /// The Store's door: full width, chevron at the end, opening the real store over the
    /// page — it comes back here the moment it's done.
    private var storeDoor: some View {
        Button {
            showStore = true
        } label: {
            HStack(spacing: 12) {
                IconView("cart")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("onboarding.open_module_store")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("onboarding.store_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
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
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(OnboardingPressStyle())
    }

    /// Import from anywhere: paste the module's manifest link, check it's an https link,
    /// hand it to the manager the Store itself uses, and say plainly what happened.
    private var importCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("onboarding.import_module")
                .font(.body.weight(.semibold))

            Text("onboarding.import_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField("onboarding.import_hint", text: $importURL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(importError == nil ? Color.primary.opacity(0.08) : Color.orange.opacity(0.5),
                                          lineWidth: 1)
                    )

                Button {
                    importFromLink()
                } label: {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 44, height: 40)
                    } else {
                        Text("common.add")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Color.primary.opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(OnboardingPressStyle())
                .disabled(isImporting)
            }

            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
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
    }

    private func importFromLink() {
        let trimmed = importURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            importError = String(localized: "onboarding.bad_link")
            return
        }
        importError = nil
        isImporting = true
        let before = moduleManager.modules.count
        Task {
            await moduleManager.addModule(from: url)
            isImporting = false
            if moduleManager.modules.count > before {
                importURL = ""
                importError = nil
            } else {
                importError = moduleManager.errorMessage ?? String(localized: "onboarding.import_failed")
            }
        }
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

// MARK: - Store entry icon

/// A catalog entry's icon, drawn the same way everywhere the store shows one: the image
/// when it loads, a monogram tile when there isn't one.
struct ModuleStoreEntryIcon: View {
    let entry: ModuleStoreEntry
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let urlString = entry.iconURL, !urlString.isEmpty {
                CachedAsyncImage(urlString: urlString)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    Text(verbatim: String(entry.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityHidden(true)
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
