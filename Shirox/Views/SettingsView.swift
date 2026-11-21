import AuthenticationServices
import Combine
import SwiftUI

// MARK: - Root Settings View

// The shared row, list, section and tile components live in SettingsDesign.swift; the
// redesigned system moved there so every page builds on one file.

#if !os(tvOS)
/// The window a sign-in sheet hangs from: the app's key window, or nil when there's none.
@MainActor
func keyPresentationAnchor() -> ASPresentationAnchor? {
    #if os(macOS)
    return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
    #else
    return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    #endif
}
#endif

struct SettingsView: View {
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @ObservedObject private var simklAuth = SimklAuthManager.shared
    @ObservedObject private var providerManager = ProviderManager.shared
    @EnvironmentObject private var moduleManager: ModuleManager
    @AppStorage("preferredQuality") private var preferredQuality: String = "auto"
    @State private var totalUsage = 0
#if !os(tvOS)
    /// The introduction, again, for whoever wants a replay.
    @State private var showOnboardingReplay = false
#endif
    /// The services signed in, short, for the Sources row.
    private var providersSubtitle: String {
        let services = [
            aniListAuth.isLoggedIn ? "AniList" : nil,
            malAuth.isLoggedIn ? "MAL" : nil,
            simklAuth.isLoggedIn ? "Simkl" : nil
        ].compactMap { $0 }
        return services.isEmpty ? String(localized: "library.sign_in") : services.joined(separator: ", ")
    }

    private var modulesSubtitle: String? {
        moduleManager.activeModule?.sourceName ?? providerManager.primary?.providerType.displayName
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                // Grouped, as the Mac's own settings are; a List there draws one long flat column.
                Form { sections }
                    .formStyle(.grouped)
                #else
                List { sections }
                #endif
            }
            .softScrollEdges()
            .navigationTitle("settings.settings")
            #if !os(tvOS)
            .navigationDestinationCompat(isPresented: $showOnboardingReplay) {
                OnboardingView()
                    .environmentObject(moduleManager)
            }
            #endif
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                PlayerPresenter.shared.resetToAppOrientation()
                Task {
                    totalUsage = await CacheManager.shared.totalDiskUsage
                }
            }
            #elseif os(macOS)
            .onAppear {
                Task { totalUsage = await CacheManager.shared.totalDiskUsage }
            }
            #endif
        }
    }

    @ViewBuilder
    private var sections: some View {
            // Accounts: notifications live here; the tracker and integration accounts
            // moved under Sources, where the rest of what the app plays from already was.
            Section {
                NavigationLink {
                    NotificationsSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "bell",
                        title: String(localized: "settings.notifications"),
                        subtitle: String(localized: "settings.notifications_subtitle")
                    )
                }
            } header: {
                SettingsSectionHeader("settings.section_you")
            }

            // Where things play.
            Section {
                NavigationLink {
                    PlayerSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "play.tv",
                        title: String(localized: "settings.player")
                    )
                }

                NavigationLink {
                    SubtitleSettingsPage()
                } label: {
                    SettingsNavRow(
                        icon: "captions.bubble",
                        title: String(localized: "settings.subtitles"),
                        subtitle: String(localized: "settings.subtitles_subtitle")
                    )
                }

                #if !os(tvOS)
                NavigationLink {
                    ReaderSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "book",
                        title: String(localized: "settings.reader"),
                        subtitle: String(localized: "settings.reader_subtitle")
                    )
                }
                #endif
            } header: {
                SettingsSectionHeader("settings.section_playback")
            }

            Section {
                NavigationLink {
                    LibrarySettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "books.vertical",
                        title: String(localized: "common.library"),
                        subtitle: String(localized: "settings.lists_and_matching")
                    )
                }

                NavigationLink {
                    DownloadsSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "arrow.down.circle",
                        title: String(localized: "common.downloads"),
                        subtitle: String(localized: "settings.downloads_subtitle")
                    )
                }

                #if !os(tvOS)
                NavigationLink {
                    StorageSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "internaldrive",
                        title: String(localized: "settings.storage_and_cache"),
                        subtitle: totalUsage > 0 ? Self.formattedBytes(totalUsage) : nil
                    )
                }
                #endif
            } header: {
                SettingsSectionHeader("settings.section_library_storage")
            }

            // What the app plays from — one Sources section: the tracker and integration
            // accounts, and the modules. No separate Sources & Integrations category.
            Section {
                NavigationLink {
                    SourcesIntegrationsView()
                } label: {
                    SettingsNavRow(
                        icon: "person.2",
                        title: String(localized: "settings.sources"),
                        subtitle: providersSubtitle
                    )
                }

                NavigationLink {
                    ModuleListView()
                        .environmentObject(moduleManager)
                } label: {
                    SettingsNavRow(
                        icon: "puzzlepiece.extension",
                        title: String(localized: "common.modules"),
                        subtitle: modulesSubtitle
                    )
                }
            } header: {
                SettingsSectionHeader("settings.section_sources")
            }

            // The app itself.
            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "gearshape",
                        title: String(localized: "settings.general"),
                        subtitle: String(localized: "settings.general_subtitle")
                    )
                }

                NavigationLink {
                    CustomizationSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "paintpalette",
                        title: String(localized: "settings.customization"),
                        subtitle: String(localized: "settings.customization_subtitle")
                    )
                }

                #if !os(tvOS)
                NavigationLink {
                    BackupSettingsView()
                } label: {
                    SettingsNavRow(
                        icon: "arrow.up.arrow.down.circle",
                        title: String(localized: "settings.backup_and_restore")
                    )
                }
                #endif

                NavigationLink {
                    SettingsViewLogger()
                } label: {
                    SettingsNavRow(
                        icon: "terminal",
                        title: String(localized: "settings.app_logs")
                    )
                }

                NavigationLink {
                    ChangelogView()
                } label: {
                    SettingsNavRow(
                        icon: "clock.arrow.circlepath",
                        title: String(localized: "settings.changelog")
                    )
                }

                // Expert settings for blocked regions, deliberately last.
                NavigationLink { AdvancedNetworkSettingsView() } label: { SettingsNavRow(icon: "network", title: String(localized: "settings.advanced_network")) }

                #if !os(tvOS)
                Button {
                    showOnboardingReplay = true
                } label: {
                    SettingsNavRow(
                        icon: "graduationcap",
                        title: String(localized: "settings.replay_introduction"),
                        subtitle: String(localized: "settings.replay_introduction_subtitle"),
                        showsChevron: true
                    )
                }
                .buttonStyle(SettingsRowPressStyle())
                #endif
            } header: {
                SettingsSectionHeader("settings.section_app")
            }

            // Device facts close the list, with no section header of their own — the block
            // never needed a category name. The legal pages (imprint, privacy, contributors,
            // licences) live on the project's website; TMDB's attribution sits with the
            // changelog's credits, the unobtrusive place its terms still require.
            Section {
                copyRow(SettingsNavRow(icon: Platform.icon, title: String(localized: "settings.platform"), subtitle: Platform.summary),
                        copying: Platform.summary, toast: String(localized: "settings.platform_copied"))
                copyRow(SettingsNavRow(icon: "info.circle", title: String(localized: "modules.version"), subtitle: Self.appVersion),
                        copying: Self.appVersion, toast: String(localized: "settings.version_copied"))
            }
    }

    /// A row that copies its value when tapped, for pasting into a bug report. Apple TV has no
    /// clipboard, so it's a plain row there.
    @ViewBuilder
    private func copyRow(_ row: SettingsNavRow, copying value: String, toast: String) -> some View {
        #if os(tvOS)
        row
        #else
        Button {
            Clipboard.copy(value)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            ToastManager.shared.show(message: toast, type: .success, duration: 1.6)
        } label: {
            row.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #endif
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    static func formattedBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 KB" }
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        } else {
            return String(format: "%.0f KB", Double(bytes) / 1_000)
        }
    }
}

// MARK: - Platform

/// The device and system Shirox runs on, for the Platform row: "iPhone 14 Pro · iOS 27.0".
private enum Platform {
    static var summary: String { "\(deviceName) · \(systemName)" }

    static var icon: String {
        #if os(macOS)
        return "desktopcomputer"
        #elseif os(tvOS)
        return "appletv"
        #else
        if runsOnMac { return "desktopcomputer" }
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
    }

    #if !os(macOS)
    /// Catalyst, or the iPad app on Apple silicon.
    private static var runsOnMac: Bool {
        ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac
    }
    #endif

    private static var systemName: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        #if os(macOS)
        return "macOS \(v.majorVersion).\(v.minorVersion)"
        #else
        if runsOnMac { return "macOS \(v.majorVersion).\(v.minorVersion)" }
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #endif
    }

    /// The marketing name where it's known, else the model identifier ("iPad15,3"). The system
    /// only hands out the identifier, and since iOS 16 the device name is just "iPhone".
    private static var deviceName: String {
        let id = modelIdentifier
        if let name = marketingNames[id] { return name }
        #if os(macOS)
        return id.isEmpty ? "Mac" : id
        #else
        if runsOnMac { return id.isEmpty ? "Mac" : id }
        return id.isEmpty ? UIDevice.current.model : id
        #endif
    }

    private static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
        #else
        #if os(macOS)
        return sysctlString("hw.model")
        #else
        if runsOnMac { return sysctlString("hw.model") }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(bytes: $0.prefix { $0 != 0 }, encoding: .utf8) ?? "" }
        #endif
        #endif
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }

    /// iPhones Shirox runs on (iOS 15 and later). iPads, Macs and Apple TVs show their identifier.
    private static let marketingNames: [String: String] = [
        "iPhone8,1": "iPhone 6s", "iPhone8,2": "iPhone 6s Plus", "iPhone8,4": "iPhone SE",
        "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7", "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8", "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max", "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air", "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone19,4": "iPhone Duo"
    ]
}

// MARK: - Sources & Integrations

/// AniList, MyAnimeList, Simkl and Discord: the accounts Shirox connects to, the tracking
/// they mirror, and the library syncing between them. Modules are managed on their own page.
struct SourcesIntegrationsView: View {
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @ObservedObject private var simklAuth = SimklAuthManager.shared
    @ObservedObject private var providerManager = ProviderManager.shared
    @StateObject private var librarySync = LibrarySyncService.shared
    @State private var pendingSyncRun: SyncRun?
    @State private var previewRun: SyncRun?
    @State private var overwritePlan: LibraryOverwritePlan?

    @AppStorage("aniListTrackingEnabled") private var aniListTrackingEnabled = true
    @AppStorage("malTrackingEnabled") private var malTrackingEnabled = true
    @AppStorage("skipReWatchTracking") private var skipReWatchTracking = true
    @AppStorage("simklTrackingEnabled") private var simklTrackingEnabled = true
    @AppStorage(SyncTargets.key) private var syncTargetsRaw = ""
    @AppStorage("rateOnFinish") private var rateOnFinish = true

    /// The window a sign-in sheet hangs from.
    private var anchor: ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #elseif os(tvOS)
        return ASPresentationAnchor()
        #else
        return keyPresentationAnchor() ?? ASPresentationAnchor()
        #endif
    }

    /// The sync sections are generated from whoever is signed in. Defined once on
    /// `LibrarySyncService` so reads and the UI can never disagree about who that is.
    private var signedInSides: [LibrarySide] { librarySync.signedInSides }

    private var anyTrackingSource: Bool {
        aniListAuth.isLoggedIn || malAuth.isLoggedIn || simklAuth.isLoggedIn
    }

    var body: some View {
        SettingsList {
            sourceSection

            trackerSection

            #if !os(tvOS)
            Section {
                NavigationLink {
                    DiscordSettingsView()
                } label: {
                    DiscordSettingsRow()
                }
            } footer: {
                Text("settings.discord_row_note")
            }
            #endif

            if anyTrackingSource {
                trackingSection
            }

            if signedInSides.count >= 2 {
                Section {
                    ForEach(signedInSides, id: \.self) { side in
                        Toggle(side.name, isOn: mirrorBinding(for: side))
                            .switchTint()
                    }
                } header: {
                    SettingsSectionHeader("settings.mirror_edits")
                } footer: {
                    Text("settings.an_edit_you_make_to")
                }

                SettingsSection(titleKey: "settings.sync_library") {
                    ForEach(SyncRun.runs(in: .sync, among: signedInSides)) { run in
                        syncRow(run)
                    }
                }

                SettingsSection(titleKey: "settings.overwrite_library") {
                    ForEach(SyncRun.runs(in: .overwrite, among: signedInSides)) { run in
                        syncRow(run)
                    }
                }

                SettingsSection(titleKey: "settings.mirror_library") {
                    ForEach(SyncRun.runs(in: .mirror, among: signedInSides)) { run in
                        syncRow(run)
                    }
                }
            }
        }
        .softScrollEdges()
        .navigationTitle("settings.sources")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(
            pendingSyncRun?.title ?? String(localized: "settings.sync_library"),
            isPresented: Binding(
                get: { pendingSyncRun != nil },
                set: { if !$0 { pendingSyncRun = nil } }
            ),
            presenting: pendingSyncRun
        ) { run in
            Button(run.confirmButtonTitle, role: run.isDestructive ? .destructive : nil) {
                pendingSyncRun = nil
                Task { await librarySync.sync(run) }
            }
            Button("common.cancel", role: .cancel) { pendingSyncRun = nil }
        } message: { run in
            Text(run.confirmationMessage)
        }
        .sheet(isPresented: Binding(
            get: { overwritePlan != nil && previewRun != nil },
            set: { if !$0 { overwritePlan = nil; previewRun = nil } }
        )) {
            if let plan = overwritePlan, let run = previewRun {
                OverwritePreviewSheet(run: run, plan: plan) {
                    overwritePlan = nil
                    previewRun = nil
                    Task { await librarySync.apply(plan, for: run) }
                } onCancel: {
                    overwritePlan = nil
                    previewRun = nil
                }
                .macSheetFrame()
            }
        }
    }

    // MARK: - Anime sources

    /// The metadata sources Shirox browses and searches, one account card each. The first
    /// in the order is the one the app uses first; drag to change it.
    private var sourceSection: some View {
        Section {
            ForEach(providerManager.orderedProviders, id: \.providerType) { provider in
                SourceAccountCard(
                    icon: provider.providerType.iconURL,
                    name: provider.providerType.displayName,
                    status: sourceStatus(provider.providerType),
                    isPrimary: providerManager.orderedProviders.first?.providerType == provider.providerType,
                    isSignedIn: isSignedIn(provider.providerType),
                    needsReauth: needsReauth(provider.providerType),
                    onPrimary: { providerManager.selectProvider(provider.providerType) },
                    onAuth: { toggleAuth(provider.providerType) }
                )
            }
            .onMove { from, to in
                providerManager.moveProvider(from: from, to: to)
            }
        } header: {
            SettingsSectionHeader("settings.anime_sources")
        } footer: {
            Text("settings.drag_to_reorder_the_first")
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
    }

    // MARK: - Trackers

    /// Simkl, the write-side tracker: not a browsing source, so not in the list above.
    private var trackerSection: some View {
        Section {
            SourceAccountCard(
                icon: ProviderType.simkl.iconURL,
                iconOnWhite: true,
                name: simklAuth.username ?? "Simkl",
                status: simklAuth.isLoggedIn
                    ? (simklAuth.needsReauthorization
                       ? String(localized: "settings.sign_in_again_to_allow")
                       : String(localized: "settings.signed_in"))
                    : String(localized: "settings.not_signed_in"),
                isPrimary: false,
                isSignedIn: simklAuth.isLoggedIn,
                needsReauth: simklAuth.needsReauthorization,
                onPrimary: nil,
                onAuth: {
                    if simklAuth.isLoggedIn {
                        simklAuth.logout()
                    } else {
                        simklAuth.login(presentationAnchor: anchor)
                    }
                }
            )
            if simklAuth.isLoggedIn {
                SimklBudgetRow()
            }
        } header: {
            SettingsSectionHeader("settings.section_trackers")
        } footer: {
            Text("settings.tracks_your_anime_shows_and")
        }
    }

    // MARK: - Tracking

    /// What watching mirrors where, one toggle per signed-in source.
    private var trackingSection: some View {
        SettingsSection(titleKey: "library.tracking") {
            if aniListAuth.isLoggedIn {
                Toggle("settings.track_on_anilist", isOn: $aniListTrackingEnabled)
                    .switchTint()
            }
            if malAuth.isLoggedIn {
                Toggle("settings.track_on_myanimelist", isOn: $malTrackingEnabled)
                    .switchTint()
            }
            if simklAuth.isLoggedIn {
                Toggle("settings.track_on_simkl", isOn: $simklTrackingEnabled)
                    .switchTint()
            }
            Toggle("settings.never_reduce_progress", isOn: $skipReWatchTracking)
                .switchTint()
            Toggle("settings.prompt_to_rate_after_finishing", isOn: $rateOnFinish)
                .switchTint()
        }
    }

    // MARK: - Card actions

    private func toggleAuth(_ type: ProviderType) {
        switch type {
        case .anilist:
            aniListAuth.isLoggedIn ? aniListAuth.logout() : aniListAuth.login(presentationAnchor: anchor)
        case .mal:
            malAuth.isLoggedIn ? malAuth.logout() : malAuth.login(presentationAnchor: anchor)
        case .simkl, .local:
            break
        }
    }

    private func isSignedIn(_ type: ProviderType) -> Bool {
        switch type {
        case .anilist: return aniListAuth.isLoggedIn
        case .mal:     return malAuth.isLoggedIn
        case .simkl:   return simklAuth.isLoggedIn
        case .local:   return false
        }
    }

    private func needsReauth(_ type: ProviderType) -> Bool {
        switch type {
        case .anilist: return aniListAuth.needsReauthentication
        case .mal:     return false
        case .simkl:   return simklAuth.needsReauthorization
        case .local:   return false
        }
    }

    private func sourceStatus(_ type: ProviderType) -> String {
        switch type {
        case .anilist:
            guard aniListAuth.isLoggedIn else { return String(localized: "settings.not_signed_in") }
            // A token AniList has started refusing still has `isLoggedIn` true - the token is
            // kept on purpose. Saying "Signed in" while every sync fails is what left people
            // with no idea what to do about it.
            return aniListAuth.needsReauthentication ? String(localized: "settings.sign_in_again") : String(localized: "settings.signed_in")
        case .mal: return malAuth.isLoggedIn ? String(localized: "settings.signed_in") : String(localized: "settings.not_signed_in")
        case .simkl: return simklAuth.isLoggedIn ? String(localized: "settings.signed_in") : String(localized: "settings.not_signed_in")
        case .local: return String(localized: "settings.not_signed_in")
        }
    }

    private func mirrorBinding(for side: LibrarySide) -> Binding<Bool> {
        Binding(
            get: { SyncTargets.decode(syncTargetsRaw).contains(side) },
            set: { isOn in
                var sides = SyncTargets.decode(syncTargetsRaw)
                if isOn { sides.insert(side) } else { sides.remove(side) }
                SyncTargets.save(sides)
            })
    }

    /// One row in the Sync / Overwrite / Mirror sections. Safe runs get a confirmation dialog;
    /// destructive ones get a full preview of what they would change.
    @ViewBuilder
    private func syncRow(_ run: SyncRun) -> some View {
        Button {
            if run.isDestructive {
                // Destructive runs are never launched straight from a tap - they go through a
                // preview of exactly what they would change.
                previewRun = run
                Task { overwritePlan = await librarySync.preview(run) }
            } else {
                pendingSyncRun = run
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .foregroundStyle(run.isDestructive ? Color.red : Color.accentColor)
                    Text(run.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if librarySync.isRunning {
                    Text(librarySync.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(librarySync.isRunning)
    }
}

/// One connected account: the source's icon in a tile, its name, where the account stands,
/// and the two actions it offers - sign in or out, and make primary when it isn't.
private struct SourceAccountCard: View {
    let icon: String
    var iconOnWhite = false
    let name: String
    let status: String
    var isPrimary = false
    let isSignedIn: Bool
    var needsReauth = false
    var onPrimary: (() -> Void)?
    let onAuth: () -> Void

    /// The connection state as a colour, the way a status LED reads: green for connected,
    /// amber for a session that needs re-authorizing, grey for not connected.
    private var stateColor: Color {
        if needsReauth { return .orange }
        return isSignedIn ? .green : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CachedAsyncImage(urlString: icon)
                    .frame(width: 48, height: 48)
                    .background(iconOnWhite ? Color.white : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if isPrimary {
                            IconView("star.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.yellow)
                                .accessibilityLabel(Text("settings.primary"))
                        }
                    }
                    // The status as the LED plus the words, so the state reads at a glance
                    // and in full for whoever needs the words.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 8, height: 8)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(needsReauth ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)
            }

            HStack(spacing: 10) {
                Button(action: onAuth) {
                    Text(isSignedIn ? String(localized: "settings.sign_out") : String(localized: "library.sign_in"))
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Capsule().fill((isSignedIn ? Color.red : Color.accentColor).opacity(0.14))
                        )
                        .foregroundStyle(isSignedIn ? Color.red : Color.accentColor)
                }
                .buttonStyle(.plain)

                if !isPrimary, let onPrimary {
                    Button(action: onPrimary) {
                        Text("settings.make_primary")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.08))
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                            )
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}


// MARK: - Player Settings

/// How the player plays, drives and moves through episodes — built as a console, not a
/// settings list. Four zones, each with the control its decision actually wants: the
/// engine as one wide card split in two halves, the picture quality as a six-slot ruler,
/// the hold gesture as two icon cards, the skip lengths as chip rows, and the watched
/// threshold as a dial with the number in the middle. No List, no repeated rows; every
/// setting the page has ever had is still here, persisted the same way.
struct PlayerSettingsView: View {
    fileprivate static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    @AppStorage("forceLandscape") private var forceLandscape = false
    @AppStorage("autoRotateForcedLandscape") private var autoRotateForcedLandscape = false
    @AppStorage("playerLiquidGlass") private var playerLiquidGlass = true
    @AppStorage("playerEngine") private var playerEngine = PlaybackEngineKind.native.rawValue
    @AppStorage("preferredQuality") private var preferredQuality: String = "auto"
    @AppStorage("speedBoostTolerance") private var speedBoostTolerance: Int = 10
    @AppStorage("playerHoldAction") private var playerHoldAction = "speed"
    @AppStorage("playerSkipShort") private var skipShort: Int = 10
    @AppStorage("playerSkipLong") private var skipLong: Int = 85
    @AppStorage("autoNextEpisode") private var autoNextEpisode = true
    @AppStorage("pauseWhenInactive") private var pauseWhenInactive = true
    @AppStorage("playerAmbientMode") private var ambientMode = false
    @AppStorage("playerSpatialAudio") private var spatialAudio = false
    @AppStorage("playerPlayInBackground") private var playInBackground = false
    @AppStorage("autoSkipSegments") private var autoSkipSegments = true
    @AppStorage("watchedPercentage") private var watchedPercentage = 90.0

    private let shortOptions = [5, 10, 15, 30]
    private let longOptions: [Int] = [30, 60, 85, 90, 120, 150, 180]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                engineZone
                soundZone
                gestureZone
                episodesZone
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("settings.player")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PlayerPresenter.shared.resetToAppOrientation()
        }
        #endif
    }

    // MARK: Zone pieces

    /// A zone's label: small, grey, the one piece of chrome every zone shares.
    private func zoneLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    /// The rounded container the zones' controls sit in.
    private func zone<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var zoneDivider: some View {
        Divider()
    }

    // MARK: Engine

    /// The page's headline decision: one card, two halves, the picked half carrying its
    /// checkmark, and the mpv note only when mpv is the one picked.
    private var engineZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.player_engine")
            #if !os(tvOS)
            zone {
                HStack(spacing: 10) {
                    engineHalf(title: "settings.native", symbol: "play.square.stack",
                               isSelected: playerEngine == PlaybackEngineKind.native.rawValue) {
                        playerEngine = PlaybackEngineKind.native.rawValue
                    }
                    engineHalf(title: "MPV", symbol: "movie.player",
                               isSelected: playerEngine == PlaybackEngineKind.mpv.rawValue) {
                        playerEngine = PlaybackEngineKind.mpv.rawValue
                    }
                }
                if playerEngine == PlaybackEngineKind.mpv.rawValue {
                    Text("settings.mpv_plays_more_formats_like")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            #endif
        }
    }

    /// One half of the engine card: the symbol, the name, the checkmark on the live one.
    private func engineHalf(title: LocalizedStringKey, symbol: String, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconView(symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                    .frame(width: 30)
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                IconView("checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.09 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.35 : 0.07),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: Picture & sound

    /// The rendition the player starts at, as a ruler: six equal slots with tick marks
    /// between them, the picked one filled. The labels are short by design, so nothing
    /// truncates on the narrowest phone.
    private var soundZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if !os(tvOS)
            zoneLabel("settings.preferred_quality")
            zone {
                HStack(spacing: 4) {
                    qualitySlot("player.auto", tag: "auto")
                    qualitySlot("settings.highest", tag: "highest")
                    qualitySlot(verbatim: "1080p", tag: "1080")
                    qualitySlot(verbatim: "720p", tag: "720")
                    qualitySlot(verbatim: "480p", tag: "480")
                    qualitySlot("settings.lowest", tag: "lowest")
                }
                .frame(maxWidth: .infinity)
            }

            zone {
                Toggle("settings.ambient_mode", isOn: $ambientMode)
                    .switchTint()
                #if os(iOS)
                if !Self.isMac {
                    zoneDivider
                    Toggle("settings.play_in_background", isOn: $playInBackground)
                        .switchTint()
                    zoneDivider
                    Toggle("settings.spatial_audio", isOn: $spatialAudio)
                        .switchTint()
                        .onChangeOf(spatialAudio) { _ in AppAudioSession.applySpatialAudioSetting() }
                }
                #endif
            }
            #endif
        }
    }

    /// One ruler slot: the label centred, the picked slot filled dark with the light label.
    private func qualitySlot(_ title: LocalizedStringKey, tag: String) -> some View {
        let isSelected = preferredQuality == tag
        return Button {
            guard preferredQuality != tag else { return }
            preferredQuality = tag
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? Color.primary.opacity(0.85) : Color.primary.opacity(0.05))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private func qualitySlot(verbatim text: String, tag: String) -> some View {
        let isSelected = preferredQuality == tag
        return Button {
            guard preferredQuality != tag else { return }
            preferredQuality = tag
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(verbatim: text)
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? Color.primary.opacity(0.85) : Color.primary.opacity(0.05))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    // MARK: Gestures

    /// What a finger does to the video: the hold's two meanings as icon cards, how strictly
    /// the hold is read, the orientation, and the chrome's look on systems that offer one.
    private var gestureZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.pane_controls")
            zone {
                #if !os(macOS)
                orientationRow
                zoneDivider
                #endif

                #if os(iOS)
                if #available(iOS 26.0, *) {
                    Toggle("settings.liquid_glass_controls", isOn: $playerLiquidGlass)
                        .switchTint()
                    zoneDivider
                }
                #endif

                #if !os(macOS)
                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.hold_action")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        holdCard(title: "player.2_speed", symbol: "speedometer",
                                 isSelected: playerHoldAction == "speed") {
                            playerHoldAction = "speed"
                        }
                        holdCard(title: "settings.save_frame_to_photos", symbol: "photo.on.rectangle.angled",
                                 isSelected: playerHoldAction == "saveFrame") {
                            playerHoldAction = "saveFrame"
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.hold_tolerance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("settings.hold_tolerance", selection: $speedBoostTolerance) {
                        Text("settings.strict").tag(10)
                        Text("settings.relaxed").tag(30)
                        Text("settings.very_relaxed").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                #endif

                #if os(iOS)
                zoneDivider
                Toggle("settings.pause_for_control_center", isOn: $pauseWhenInactive)
                    .switchTint()
                #endif
            }
        }
    }

    /// The orientation switch and the auto-rotate that follows it, with glyphs that say
    /// what each switch moves.
    #if !os(macOS)
    private var orientationRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconView("rotate.landscape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(forceLandscape ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                    .frame(width: 26)
                Toggle("settings.force_landscape_mode", isOn: $forceLandscape)
                    .switchTint()
                    #if os(iOS)
                    .onChangeOf(forceLandscape) {
                        PlayerPresenter.shared.resetToAppOrientation(shouldRotate: true)
                    }
                    #endif
            }
            if forceLandscape, !Self.isMac {
                HStack(spacing: 12) {
                    IconView("arrow.triangle.2.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .frame(width: 26)
                    Toggle("settings.auto_rotate_in_landscape", isOn: $autoRotateForcedLandscape)
                        .switchTint()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: forceLandscape)
    }
    #endif

    /// One of the hold's meanings: icon over name, the picked one outlined.
    private func holdCard(title: LocalizedStringKey, symbol: String, isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                IconView(symbol)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.09 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.35 : 0.07),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: Episodes

    /// Getting through episodes: the two skip lengths as chips, what skips itself, and the
    /// watched threshold as a dial — the number in the middle, the ring showing the share.
    private var episodesZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.pane_episodes")
            zone {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.skip_duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(shortOptions, id: \.self) { value in
                            skipChip(value, isSelected: skipShort == value) { skipShort = value }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.long_skip_duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                        ForEach(longOptions, id: \.self) { value in
                            skipChip(value, isSelected: skipLong == value) { skipLong = value }
                        }
                    }
                }

                zoneDivider

                Toggle("settings.auto_skip_segments", isOn: $autoSkipSegments)
                    .switchTint()
                zoneDivider
                Toggle("settings.auto_next_episode", isOn: $autoNextEpisode)
                    .switchTint()
                zoneDivider
                Toggle("settings.reverse_episode_list_by_default", isOn: EpisodeSortManager.shared.$defaultReverseSort)
                    .switchTint()

                zoneDivider

                watchedDial
            }
        }
    }

    private func skipChip(_ value: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("common.seconds_short \(value)")
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? Color.primary.opacity(0.85) : Color.primary.opacity(0.05))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    /// The watched threshold: a ring that fills to the share, the percentage in the middle,
    /// and the slider under it for the fine setting.
    private var watchedDial: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: watchedPercentage / 100)
                        .stroke(Color.primary.opacity(0.75), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.2), value: watchedPercentage)
                    Text("common.percent \(Int(watchedPercentage))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .padding(4)
                }
                .frame(width: 74, height: 74)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("settings.episode_progress_threshold"))
                .accessibilityValue(Text("common.percent \(Int(watchedPercentage))"))

                VStack(alignment: .leading, spacing: 3) {
                    Text("settings.episode_progress_threshold")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
            }

            #if !os(tvOS)
            Slider(value: $watchedPercentage, in: 50...100, step: 1)
            #endif
        }
    }
}


// MARK: - Subtitle Settings

/// How subtitles look and sit in every video, set ahead of time — the player's own subtitle
/// sheet changes the same things, and a track's own pick stays in the player. The preview
/// stays pinned above the controls while everything under it scrolls.
struct SubtitleSettingsPage: View {
    @ObservedObject private var settings = SubtitleSettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            preview
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            styleList
        }
        .navigationTitle("settings.subtitles")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var styleList: some View {
        List {
            styleSection
            backgroundSection
            #if !os(tvOS)
            positionSection
            timingSection
            #endif
            Section {
                Button("settings.restore_defaults", role: .destructive) { settings.restoreDefaults() }
            } footer: {
                Text("settings.styled_ass_subtitles_keep_their")
            }
        }
        .listStyle(.insetGrouped)
        .softScrollEdges()
    }

    // MARK: Sections

    private var styleSection: some View {
        SettingsSection(titleKey: "settings.style_section") {
            Toggle("player.show_subtitles", isOn: $settings.enabled)
                .switchTint()
            if settings.enabled {
                #if !os(tvOS)
                ColorPicker("settings.text_color", selection: $settings.foregroundColor, supportsOpacity: false)
                #endif
                SubtitleFontRow(settings: settings)
                #if os(tvOS)
                // Apple TV has no slider, so its size comes from the presets.
                Picker("player.size", selection: sizeSelection) {
                    ForEach(PlayerSubtitleMenu.sizes, id: \.points) { size in
                        Text(size.name).tag(size.points)
                    }
                    if !PlayerSubtitleMenu.sizes.contains(where: { $0.points == settings.fontSize }) {
                        Text("settings.points \(Int(settings.fontSize.rounded()))").tag(settings.fontSize)
                    }
                }
                #else
                sliderRow(String(localized: "player.size"), value: $settings.fontSize, in: 12...40, step: 1,
                          text: "\(Int(settings.fontSize))")
                sliderRow(String(localized: "settings.shadow"), value: $settings.shadowRadius, in: 0...8, step: 0.5,
                          text: String(format: "%.1f", settings.shadowRadius))
                #endif
            }
        }
    }

    private var backgroundSection: some View {
        SettingsSection(titleKey: "settings.background") {
            Toggle("settings.show_background", isOn: $settings.backgroundEnabled)
                .switchTint()
            #if !os(tvOS)
            if settings.backgroundEnabled {
                ColorPicker("settings.color", selection: $settings.backgroundColor, supportsOpacity: false)
                sliderRow(String(localized: "settings.opacity"), value: $settings.backgroundOpacity, in: 0.1...1, step: 0.05,
                          text: String(localized: "common.percent \(Int((settings.backgroundOpacity * 100).rounded()))"))
                sliderRow(String(localized: "settings.rounding"), value: $settings.backgroundCornerRadius, in: 0...20, step: 1,
                          text: String(localized: "settings.points \(Int(settings.backgroundCornerRadius))"))
            }
            #endif
        }
    }

    #if !os(tvOS)
    private var positionSection: some View {
        SettingsSection(titleKey: "settings.position") {
            sliderRow(String(localized: "settings.bottom_padding"), value: $settings.bottomPadding, in: SubtitleSettingsManager.bottomPaddingRange, step: 5,
                      text: String(localized: "settings.points \(Int(settings.bottomPadding))"))
        }
    }

    private var timingSection: some View {
        SettingsSection(titleKey: "shared.sync") {
            HStack {
                Text("player.delay")
                Spacer()
                Text(PlayerSubtitleMenu.delayLabel(settings.delaySeconds))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Button("settings.reset_delay") { settings.delaySeconds = 0 }
                .disabled(settings.delaySeconds == 0)
        }
    }
    #endif

    // MARK: Preview

    /// A line of subtitle over a frame, drawn as the player draws it. The frame is bright, the
    /// case the outline and shadow are there for. Nothing over it while subtitles are off.
    private var preview: some View {
        ZStack(alignment: .bottom) {
            Image("SubtitlePreview")
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
            if settings.enabled {
                subtitleLine
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private var subtitleLine: some View {
        Text("settings.did_he_give_you_any")
            .font(settings.font(size: min(settings.fontSize, 32)))
            .foregroundStyle(settings.foregroundColor)
            .shadow(color: .black, radius: 0, x: -1, y: 0)
            .shadow(color: .black, radius: 0, x: 1, y: 0)
            .shadow(color: .black, radius: 0, x: 0, y: -1)
            .shadow(color: .black, radius: 0, x: 0, y: 1)
            .shadow(color: .black.opacity(0.8), radius: settings.shadowRadius)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, settings.backgroundEnabled ? 6 : 0)
            .background(settings.backgroundEnabled
                        ? RoundedRectangle(cornerRadius: settings.backgroundCornerRadius).fill(settings.backgroundFill)
                        : nil)
            .padding(.bottom, 16)
    }

    /// A slider under its label, the current value at the label's end.
    #if !os(tvOS)
    private func sliderRow(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                           step: Double, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(text)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
    #endif
}


// MARK: - Reader Settings

/// How the manga reader turns pages and answers touches: a page mock showing the tap zones
/// the way they sit on screen, and the toggles under the area they change.
#if !os(tvOS)
struct ReaderSettingsView: View {
    @AppStorage("readerLiquidGlass") private var readerLiquidGlass = true
    @AppStorage("readerPageCurl") private var readerPageCurl = true
    @AppStorage("readerPortraitOnly") private var readerPortraitOnly = false
    @AppStorage(ReaderTapZone.enabledKey) private var tapZones = true
    @AppStorage(ReaderTapZone.reversedKey) private var tapZonesReversed = false

    var body: some View {
        List {
            zoneDiagramSection
            gesturesSection
            pagesSection
            styleSection
        }
        .softScrollEdges()
        .navigationTitle("settings.reader")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Diagram

    /// The page with its two tap zones, as the reader really splits it — right goes forward,
    /// left goes back, and which physical side does which flips when the direction is
    /// reversed. Dead in the diagram when tap zones are off.
    private var zoneDiagramSection: some View {
        Section {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    zone(label: tapZonesReversed ? "reader.forward_zone" : "reader.back_zone",
                         icon: tapZonesReversed ? "arrow.right" : "arrow.left")
                    zone(label: tapZonesReversed ? "reader.back_zone" : "reader.forward_zone",
                         icon: tapZonesReversed ? "arrow.left" : "arrow.right")
                }
                Text(tapZones ? Self.zoneCaption : Self.zoneOffCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .opacity(tapZones ? 1 : 0.45)
            .listRowBackground(Color.clear)
        }
    }

    private func zone(label: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 6) {
            IconView(icon)
                .font(.title3)
            Text(label)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Sections

    private var gesturesSection: some View {
        SettingsSection(titleKey: "settings.tap_zones") {
            Toggle("settings.tap_sides_to_scroll_or", isOn: $tapZones)
                .switchTint()
            Toggle("reader.reverse_direction", isOn: $tapZonesReversed)
                .switchTint()
                .disabled(!tapZones)
        }
    }

    private var pagesSection: some View {
        SettingsSection(titleKey: "settings.turning_pages") {
            // A Mac's reader turns pages with a slide; there's no curl to turn off.
            #if os(iOS)
            Toggle("reader.page_curl", isOn: $readerPageCurl)
                .switchTint()
            // An iPad turns everywhere, so this only means something on iPhone.
            if UIDevice.current.userInterfaceIdiom == .phone {
                Toggle("settings.portrait_only", isOn: $readerPortraitOnly)
                    .switchTint()
            }
            #endif
        }
    }

    private var styleSection: some View {
        SettingsSection(titleKey: "settings.style") {
            if #available(iOS 26.0, macOS 26.0, *) {
                Toggle("settings.liquid_glass_controls", isOn: $readerLiquidGlass)
                    .switchTint()
            } else {
                Text("settings.liquid_glass_reader_controls_need \(Self.systemName)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static var zoneCaption: String {
        #if os(macOS)
        String(localized: "settings.click_the_right_side_to")
        #else
        String(localized: "settings.tap_the_right_side_to")
        #endif
    }

    private static var zoneOffCaption: String {
        #if os(macOS)
        String(localized: "settings.a_click_anywhere_on_a")
        #else
        String(localized: "settings.a_tap_anywhere_on_a")
        #endif
    }

    private static var systemName: String {
        #if os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }
}
#endif


// MARK: - Library Settings

/// The library's own behaviour, set out the way the library itself reads: the tab order as
/// its own door, the title languages as a numbered ladder you climb or descend with the
/// arrows, the score format picked from five live previews of what a score actually looks
/// like in each, and the on-device library's tracking and clear-out. Every setting keeps
/// its key and its persistence.
struct LibrarySettingsView: View {
    @AppStorage("titleLanguagePriority") private var titlePriority = "english,romaji,native"
    @AppStorage("localAutoTrackEnabled") private var localAutoTrackEnabled = true
    @AppStorage("localScoreFormat") private var localScoreFormatRaw: String = ScoreFormat.point10Decimal.rawValue
    @AppStorage(NewEpisodeTracker.badgesKey) private var newEpisodeBadges = true
    @State private var showClearLocalLibrary = false

    private var orderedLanguages: [String] {
        titlePriority.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    private var scoreFormat: ScoreFormat {
        ScoreFormat(rawValue: localScoreFormatRaw) ?? .point10Decimal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                orderDoor
                languageLadder
                scoreShelf
                localCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("common.library")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("settings.clear_local_library", isPresented: $showClearLocalLibrary) {
            Button("search.clear", role: .destructive) { LocalLibraryManager.shared.clearAll() }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.this_permanently_removes_all_on")
        }
    }

    // MARK: Pieces

    private func zoneLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Tab order

    /// The tabs' order and custom lists live one push away, as a full-width door.
    private var orderDoor: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.list_order")
            NavigationLink {
                LibraryListOrderView()
            } label: {
                HStack(spacing: 12) {
                    IconView("list.bullet.indent")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    Text("settings.list_order_and_custom_lists")
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    IconView("chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(SettingsRowPressStyle())
        }
    }

    // MARK: Title languages

    /// Which language a title shows in first. Each rung shows its place, its name, and the
    /// arrows that move it — a ladder you climb, not a hidden drag handle.
    private var languageLadder: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.matching")
            card {
                ForEach(Array(orderedLanguages.enumerated()), id: \.element) { index, lang in
                    if index > 0 {
                        Divider()
                    }
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(lang.capitalized)
                            .font(.body.weight(.medium))
                        Spacer(minLength: 8)
                        VStack(spacing: 2) {
                            Button {
                                moveLanguage(from: index, to: index - 1)
                            } label: {
                                IconView("chevron.up")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(index == 0 ? AnyShapeStyle(Color.secondary.opacity(0.55)) : AnyShapeStyle(Color.primary))
                                    .frame(width: 34, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            Button {
                                moveLanguage(from: index, to: index + 1)
                            } label: {
                                IconView("chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(index == orderedLanguages.count - 1 ? AnyShapeStyle(Color.secondary.opacity(0.55)) : AnyShapeStyle(Color.primary))
                                    .frame(width: 34, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(index == orderedLanguages.count - 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func moveLanguage(from: Int, to: Int) {
        var langs = orderedLanguages
        guard langs.indices.contains(from), langs.indices.contains(to) else { return }
        langs.swapAt(from, to)
        titlePriority = langs.joined(separator: ",")
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: Score format

    /// The score scale, chosen from five live previews: each option shows what the same
    /// series — rated 8.5 of 10 — would read as in that format, so the pick needs no
    /// guessing.
    private var scoreShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.score_format")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([ScoreFormat.point100, .point10Decimal, .point10, .point5, .point3], id: \.rawValue) { format in
                        scoreCard(format)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func scoreCard(_ format: ScoreFormat) -> some View {
        let isSelected = scoreFormat == format
        return Button {
            guard localScoreFormatRaw != format.rawValue else { return }
            localScoreFormatRaw = format.rawValue
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            VStack(spacing: 6) {
                Text(verbatim: Self.sampleScore(in: format))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Text(Self.formatTitle(format))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(width: 108, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.09 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.35 : 0.07),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    /// What a rating of 8.5/10 reads as in the format — the 3-point scale rounds to its
    /// thumbs-up, the 5-star to the nearest half. This is a preview, not a stored score.
    static func sampleScore(in format: ScoreFormat) -> String {
        let rating = 8.5 / 10.0
        switch format {
        case .point100:      return "85"
        case .point10Decimal: return "8.5"
        case .point10:       return "9"
        case .point5:        return "4.5"
        case .point3:        return "2/3"
        }
    }

    /// The format's own name, from the same keys the old picker used.
    static func formatTitle(_ format: ScoreFormat) -> String {
        switch format {
        case .point100:       return String(localized: "settings.100_point")
        case .point10Decimal: return String(localized: "settings.10_point_decimal")
        case .point10:        return String(localized: "settings.10_point")
        case .point5:         return String(localized: "settings.5_star")
        case .point3:         return String(localized: "settings.3_point")
        }
    }

    // MARK: On-device library

    /// Tracking, badges, and the way out — the on-device library's own behaviour.
    private var localCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.local_library")
            card {
                Toggle("settings.auto_track_what_you_watch", isOn: $localAutoTrackEnabled)
                    .switchTint()
                Divider()
                Toggle("settings.new_episode_badges", isOn: $newEpisodeBadges)
                    .switchTint()
                Divider()
                Button(role: .destructive) {
                    showClearLocalLibrary = true
                } label: {
                    HStack(spacing: 12) {
                        IconView("trash")
                            .font(.system(size: 15))
                            .frame(width: 26)
                        Text("settings.clear_local_library")
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Library List Order View

struct LibraryListOrderView: View {
    @AppStorage("libraryStatusOrder") private var statusOrderRaw: String = MediaListStatus.allCases.map(\.rawValue).joined(separator: ",")

    private var statuses: [MediaListStatus] {
        let saved = statusOrderRaw.components(separatedBy: ",").compactMap(MediaListStatus.init(rawValue:))
        let missing = MediaListStatus.allCases.filter { !saved.contains($0) }
        return saved + missing
    }

    private var customListNames: [String] {
        UserDefaults.standard.stringArray(forKey: "libraryCustomListNames") ?? []
    }

    var body: some View {
        List {
            Section {
                ForEach(statuses) { status in
                    Label(status.displayName, icon: icon(for: status))
                }
                .onMove { from, to in
                    var list = statuses
                    list.move(fromOffsets: from, toOffset: to)
                    statusOrderRaw = list.map(\.rawValue).joined(separator: ",")
                }
            } header: {
                SettingsSectionHeader("settings.drag_to_reorder_status_tabs")
            }

            if !customListNames.isEmpty {
                Section {
                    ForEach(customListNames, id: \.self) { name in
                        Label(name, icon: "list.star")
                    }
                } header: {
                    SettingsSectionHeader("library.custom_lists")
                } footer: {
                    Text("settings.custom_lists_are_managed_on")
                }
            }
        }
        .softScrollEdges()
        .navigationTitle("settings.list_order")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        #endif
    }

    private func icon(for status: MediaListStatus) -> String {
        switch status {
        case .current:   return "play.circle"
        case .planning:  return "bookmark"
        case .completed: return "checkmark.circle"
        case .dropped:   return "xmark.circle"
        case .paused:    return "pause.circle"
        case .repeating: return "arrow.counterclockwise.circle"
        }
    }
}

// MARK: - Downloads Settings

/// How episodes and chapters come down, laid out the way a download manager reads: the
/// quality as five label-only tiles — no description lines, nothing cut off, every option
/// fully visible on every iPhone width — the concurrency as one big − / number / + stepper,
/// the automation as icon rows, and what's on disk as a card with the one button that
/// clears it. Every quality option and every setting the page had is preserved.
struct DownloadsSettingsView: View {
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @AppStorage("backgroundDownloadsEnabled") private var backgroundDownloadsEnabled = true
    @AppStorage("autoResumeDownloads") private var autoResumeDownloads = false
    @AppStorage("autoDeleteWatched") private var autoDeleteWatched = false
    @AppStorage("downloadQuality") private var downloadQuality = "highest"
    #if !os(tvOS)
    @State private var downloadsSize = 0
    @State private var showDeleteDownloadsConfirmation = false
    #endif

    private struct QualityOption: Identifiable {
        let tag: String
        let titleKey: LocalizedStringKey
        let symbol: String
        var id: String { tag }
    }

    private let qualityOptions: [QualityOption] = [
        .init(tag: "highest", titleKey: "settings.best", symbol: "sparkles"),
        .init(tag: "1080", titleKey: "1080p", symbol: "4k.tv"),
        .init(tag: "720", titleKey: "720p", symbol: "tv"),
        .init(tag: "480", titleKey: "480p", symbol: "iphone.gen3"),
        .init(tag: "lowest", titleKey: "settings.smallest", symbol: "arrow.down.circle")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                qualityLadder
                concurrencyStepper
                automationCard
                #if !os(tvOS)
                diskCard
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("common.downloads")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if !os(tvOS)
        .alert("settings.delete_all_downloads_confirm", isPresented: $showDeleteDownloadsConfirmation) {
            Button("common.delete", role: .destructive) {
                DownloadManager.shared.removeAll(DownloadManager.shared.items)
                MangaDownloadManager.shared.removeAll(MangaDownloadManager.shared.items)
                downloadsSize = DownloadManager.shared.bytesOnDisk + MangaDownloadManager.shared.bytesOnDisk
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.every_downloaded_episode_and_chapter")
        }
        .onAppear {
            downloadsSize = DownloadManager.shared.bytesOnDisk + MangaDownloadManager.shared.bytesOnDisk
        }
        #endif
    }

    // MARK: Pieces

    private func zoneLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    // MARK: Quality

    /// The rendition new downloads ask for. Five tiles, each the icon over the label and
    /// nothing else — the labels are short and scale down rather than truncate, so every
    /// option reads in full from the narrowest phone to the widest tablet.
    private var qualityLadder: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.download_quality")
            HStack(spacing: 8) {
                ForEach(qualityOptions) { option in
                    qualityTile(option)
                }
            }
        }
    }

    private func qualityTile(_ option: QualityOption) -> some View {
        let isSelected = downloadQuality == option.tag
        return Button {
            guard downloadQuality != option.tag else { return }
            downloadQuality = option.tag
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            VStack(spacing: 7) {
                IconView(option.symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                    .frame(height: 24)
                Text(option.titleKey)
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.5) : Color.primary.opacity(0.06),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(option.titleKey))
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: Concurrency

    /// How many at once: one big stepper — the number carries the row, − and + on the
    /// sides with full thumb targets.
    private var concurrencyStepper: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.concurrent_downloads")
            HStack(spacing: 14) {
                stepperButton("minus", action: { if maxConcurrentDownloads > 1 { maxConcurrentDownloads -= 1 } })
                    .disabled(maxConcurrentDownloads <= 1)

                Text("\(maxConcurrentDownloads)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)

                stepperButton("plus", action: { if maxConcurrentDownloads < 5 { maxConcurrentDownloads += 1 } })
                    .disabled(maxConcurrentDownloads >= 5)
            }
            .animation(.easeOut(duration: 0.12), value: maxConcurrentDownloads)
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }) {
            IconView(symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 56, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Automation

    /// What the downloader does by itself, one icon row each.
    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            zoneLabel("settings.automation")
            VStack(spacing: 0) {
                #if os(iOS)
                automationRow(icon: "arrow.down.circle.fill", titleKey: "settings.background_downloads", toggle: $backgroundDownloadsEnabled)
                Divider().padding(.leading, 46)
                #endif
                automationRow(icon: "arrow.clockwise.circle.fill", titleKey: "settings.auto_resume_interrupted", toggle: $autoResumeDownloads)
                Divider().padding(.leading, 46)
                automationRow(icon: "trash.circle.fill", titleKey: "settings.delete_after_watching", toggle: $autoDeleteWatched)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func automationRow(icon: String, titleKey: LocalizedStringKey, toggle: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            IconView(icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(titleKey)
                .font(.body)
            Spacer(minLength: 8)
            Toggle("", isOn: toggle)
                .labelsHidden()
                .switchTint()
        }
        .padding(.vertical, 6)
    }

    // MARK: On disk

    /// What downloads take on disk, with the one button that clears them. The confirmation
    /// carries the explanation, so the card doesn't repeat it.
    #if !os(tvOS)
    private var diskCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 42, height: 42)
                IconView("internaldrive")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("settings.on_disk")
                    .font(.body.weight(.semibold))
                Text(SettingsView.formattedBytes(downloadsSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(role: .destructive) {
                showDeleteDownloadsConfirmation = true
            } label: {
                Text("common.delete")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(downloadsSize == 0)
            .opacity(downloadsSize == 0 ? 0.5 : 1)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    #endif
}

// MARK: - Storage & Cache Settings

/// What Shirox keeps on the device and how to get it back: a meter of where the space goes,
/// the data saver, and a reset for every kind of cache. The destructive buttons stay
/// destructive and confirm as before.
struct StorageSettingsView: View {
    @AppStorage(DataSaver.key) private var dataSaverEnabled = false
    @State private var imageCacheSize = 0
    @State private var websiteDataSize = 0
    @State private var tempFilesSize = 0
    @State private var continueWatchingSize = 0
    @State private var networkCacheSize = 0
    @State private var dataCacheSize = 0
    @State private var searchAliasSize = 0
    @State private var idMappingSize = 0
    @State private var episodeSortSize = 0
    @State private var totalUsage = 0
    @State private var isClearing = false
    @State private var showResetCWConfirmation = false
    @State private var downloadsSize = 0
    @State private var showDeleteDownloadsConfirmation = false

    var body: some View {
        List {
            meterSection
            dataSaverSection
            resetSection
            downloadsSection
        }
        .softScrollEdges()
        .navigationTitle("settings.storage_and_cache")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("settings.delete_all_downloads_confirm", isPresented: $showDeleteDownloadsConfirmation) {
            Button("common.delete", role: .destructive) {
                DownloadManager.shared.removeAll(DownloadManager.shared.items)
                MangaDownloadManager.shared.removeAll(MangaDownloadManager.shared.items)
                downloadsSize = DownloadManager.shared.bytesOnDisk + MangaDownloadManager.shared.bytesOnDisk
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.every_downloaded_episode_and_chapter")
        }
        .alert("settings.reset_watch_progress_confirm", isPresented: $showResetCWConfirmation) {
            Button("common.reset", role: .destructive) {
                CacheManager.shared.clearContinueWatching()
                updateCacheSizes()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            // It takes the watched marks too: the old wording promised only the Home cards, and a
            // separate Watch History reset, of data nothing writes any more, promised the marks.
            Text("settings.clears_continue_watching_and_every")
        }
        .onAppear {
            updateCacheSizes()
        }
    }

    // MARK: Meter

    /// Where the space goes, as one bar over the total. The bar's shares are the measured
    /// kinds; whatever they don't cover reads as "other".
    private var meterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(SettingsView.formattedBytes(totalUsage))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Text("settings.total_used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                UsageBar(shares: usageShares)
                    .frame(height: 8)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
        }
    }

    private var usageShares: [UsageBar.Share] {
        let known = imageCacheSize + websiteDataSize + tempFilesSize + continueWatchingSize
            + networkCacheSize + dataCacheSize + searchAliasSize + idMappingSize + episodeSortSize + downloadsSize
        let other = max(0, totalUsage - known)
        return [
            .init(label: String(localized: "settings.artwork"), size: imageCacheSize, color: Color.gray.opacity(0.9)),
            .init(label: String(localized: "common.downloads"), size: downloadsSize, color: Color.gray.opacity(0.7)),
            .init(label: String(localized: "settings.website_data_label"), size: websiteDataSize, color: Color.gray.opacity(0.55)),
            .init(label: String(localized: "settings.other_data"), size: other + tempFilesSize + continueWatchingSize + networkCacheSize + dataCacheSize + searchAliasSize + idMappingSize + episodeSortSize, color: Color.gray.opacity(0.4))
        ].filter { $0.size > 0 }
    }

    // MARK: Sections

    private var dataSaverSection: some View {
        Section {
            Toggle("settings.data_saver", isOn: $dataSaverEnabled)
                .switchTint()
        } header: {
            SettingsSectionHeader("settings.data")
        }
    }

    /// One row per kind of cache, its size at the end, tapping resets just that kind.
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                guard !isClearing else { return }
                isClearing = true
                Task {
                    await CacheManager.shared.clearEverything()
                    isClearing = false
                    updateCacheSizes()
                }
            } label: {
                LabeledContent("settings.clear_everything") {
                    if isClearing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text(SettingsView.formattedBytes(totalUsage))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.red)
            .disabled(isClearing)

            Button {
                Task {
                    await CacheManager.shared.clearImageCache()
                    updateCacheSizes()
                }
            } label: {
                LabeledContent("settings.reset_image_cache") {
                    Text(SettingsView.formattedBytes(imageCacheSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                guard !isClearing else { return }
                isClearing = true
                Task {
                    await CacheManager.shared.clearWebsiteData()
                    totalUsage -= websiteDataSize
                    websiteDataSize = 0
                    isClearing = false
                }
            } label: {
                LabeledContent("settings.reset_website_data") {
                    Text(SettingsView.formattedBytes(websiteDataSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearNetworkCache()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.reset_network_cache") {
                    Text(SettingsView.formattedBytes(networkCacheSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearDataCaches()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.reset_home_and_simkl_cache") {
                    Text(SettingsView.formattedBytes(dataCacheSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearTempFiles()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.clear_temporary_files") {
                    Text(SettingsView.formattedBytes(tempFilesSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearSearchAliases()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.reset_search_aliases") {
                    Text(SettingsView.formattedBytes(searchAliasSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearIDMappingCache()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.reset_id_mapping_cache") {
                    Text(SettingsView.formattedBytes(idMappingSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                CacheManager.shared.clearEpisodeSortPreferences()
                updateCacheSizes()
            } label: {
                LabeledContent("settings.reset_episode_sort_preferences") {
                    Text(SettingsView.formattedBytes(episodeSortSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Button {
                showResetCWConfirmation = true
            } label: {
                LabeledContent("settings.reset_watch_progress") {
                    Text(SettingsView.formattedBytes(continueWatchingSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.red)
            .disabled(isClearing)
        } header: {
            SettingsSectionHeader("settings.individual_resets")
        }
    }

    /// What downloads take on disk.
    private var downloadsSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteDownloadsConfirmation = true
            } label: {
                LabeledContent("settings.delete_all_downloads") {
                    Text(SettingsView.formattedBytes(downloadsSize))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.red)
            .disabled(downloadsSize == 0)
            // The download settings themselves are the root's Downloads row: one door,
            // and this page stays about what the downloads take.
        } header: {
            SettingsSectionHeader("common.downloads")
        } footer: {
            Text("settings.downloaded_episodes_and_chapters_arent")
        }
    }

    private func updateCacheSizes() {
        downloadsSize = DownloadManager.shared.bytesOnDisk + MangaDownloadManager.shared.bytesOnDisk
        websiteDataSize = CacheManager.shared.websiteDataSize
        tempFilesSize = CacheManager.shared.tempFilesSize
        continueWatchingSize = CacheManager.shared.continueWatchingSize
        networkCacheSize = CacheManager.shared.networkCacheSize
        dataCacheSize = CacheManager.shared.dataCacheSize
        searchAliasSize = CacheManager.shared.searchAliasSize
        idMappingSize = CacheManager.shared.idMappingSize
        episodeSortSize = CacheManager.shared.episodeSortSize
        Task {
            imageCacheSize = await CacheManager.shared.imageCacheSize
            totalUsage = await CacheManager.shared.totalDiskUsage
        }
    }
}

/// The storage meter's bar: proportional segments, in shades of gray, with the breakdown
/// under it when every kind has a name worth reading.
struct UsageBar: View {
    struct Share {
        let label: String
        let size: Int
        let color: Color
    }

    let shares: [Share]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(measured(in: geo.size.width)), id: \.name) { segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: segment.width)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shares.map { "\($0.label) \(SettingsView.formattedBytes($0.size))" }.joined(separator: ", "))
    }

    private func measured(in width: CGFloat) -> [(name: String, color: Color, width: CGFloat)] {
        let total = Double(shares.reduce(0) { $0 + $1.size })
        guard total > 0, !shares.isEmpty else { return [] }
        let usable = width - CGFloat(shares.count - 1) * 2
        return shares.map { share in
            (name: share.label, color: share.color,
             width: max(4 as CGFloat, usable * CGFloat(Double(share.size) / total)))
        }
    }
}
// MARK: - App directories

/// Where the app keeps the files it writes itself: logs, download manifests, downloads.
enum AppDirectories {
    /// The app's own Documents on iOS, which the Files app can browse. On the Mac, an
    /// unsandboxed app's Documents is the user's `~/Documents`, which macOS guards: writing
    /// logs and manifests there asked for permission to the Documents folder, and asked again
    /// on every launch of a build signed without a stable identity. Application Support needs
    /// no permission.
    static let documents: URL = {
        #if os(macOS) || targetEnvironment(macCatalyst)
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shirox", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        moveOutOfDocumentsOnce(to: base)
        return base
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }()

    /// Where the app keeps its own files: modules, caches, the local library. The system's
    /// Application Support on iOS, which is the app's alone. An unsandboxed Mac app shares
    /// `~/Library/Application Support` with every other app, so there it's a Shirox folder.
    static let applicationSupport: URL = {
        let fm = FileManager.default
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if os(macOS) || targetEnvironment(macCatalyst)
        let base = root.appendingPathComponent("Shirox", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        moveOutOfSharedSupportOnce(from: root, to: base)
        return base
        #else
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
        #endif
    }()

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Files earlier Mac builds left loose in `~/Library/Application Support`.
    private static let looseSupportFiles = [
        "modules.json", "id-mappings.json", "id-media-mappings.json", "id-tvdb-groups.json",
        "local_library.json", "pending-writes.json", "library-cache.json", "profile-cache.json",
        "home-cache.json", "simkl-write-queue.json", "LocalImports"
    ]

    /// Moves them into the Shirox folder, once. `modules.json` is a common name, so it goes only
    /// when it holds Shirox modules.
    private static func moveOutOfSharedSupportOnce(from root: URL, to base: URL) {
        let key = "movedFilesIntoSupportFolder"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let fm = FileManager.default
        for name in looseSupportFiles {
            let from = root.appendingPathComponent(name)
            let to = base.appendingPathComponent(name)
            guard fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) else { continue }
            if name == "modules.json" {
                guard let data = try? Data(contentsOf: from),
                      data.prefix(4_096).range(of: Data("scriptContent".utf8)) != nil else { continue }
            }
            try? fm.moveItem(at: from, to: to)
        }
    }

    /// Brings downloads and their manifests over from `~/Documents`, where earlier Mac builds
    /// kept them. Once only, whatever happens: if macOS is told not to allow it, the app
    /// doesn't keep asking.
    private static func moveOutOfDocumentsOnce(to base: URL) {
        let key = "movedFilesOutOfDocuments"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        moveDownloads(from: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0], to: base)
    }
    #endif

    /// Moves Shirox's downloads and their manifests from `old` to `base`. A folder goes only with
    /// its manifest beside it: `~/Documents/Downloads` is a common name, and one with no Shirox
    /// manifest next to it is the user's own, which an earlier build moved out of sight.
    static func moveDownloads(from old: URL, to base: URL) {
        let fm = FileManager.default
        for (folder, manifest) in [("Downloads", "downloads_manifest.json"),
                                   ("MangaDownloads", "manga_downloads_manifest.json")] {
            guard fm.fileExists(atPath: old.appendingPathComponent(manifest).path) else { continue }
            for name in [manifest, folder] {
                let from = old.appendingPathComponent(name)
                let to = base.appendingPathComponent(name)
                guard fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) else { continue }
                try? fm.moveItem(at: from, to: to)
            }
        }
    }
}

// MARK: - Logger Views & Utilities

private func logTypeColor(_ type: String) -> Color {
    switch type {
    case "Error":       return .red
    case "Debug":       return .blue
    case "Stream":      return .green
    case "Download":    return .orange
    case "HTMLStrings": return .purple
    default:            return .secondary
    }
}

private func logTypeIcon(_ type: String) -> String {
    switch type {
    case "Error":       return "exclamationmark.triangle.fill"
    case "Debug":       return "ladybug.fill"
    case "Stream":      return "play.circle.fill"
    case "Download":    return "arrow.down.circle.fill"
    case "HTMLStrings": return "text.alignleft"
    default:            return "gear"
    }
}

struct LogEntryRow: View {
    let entry: Logger.LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                IconView(logTypeIcon(entry.type))
                    .font(.caption)
                    .foregroundStyle(logTypeColor(entry.type))
                Text(entry.type.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(logTypeColor(entry.type))
                Spacer()
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(logTypeColor(entry.type).opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(logTypeColor(entry.type).opacity(0.18), lineWidth: 1)
        )
    }
}

struct SettingsViewLogger: View {
    @State private var entries: [Logger.LogEntry] = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @StateObject private var filterViewModel = LogFilterViewModel.shared

    private var filteredEntries: [Logger.LogEntry] {
        let base = searchText.isEmpty ? entries : entries.filter {
            $0.message.localizedCaseInsensitiveContains(searchText) || $0.type.localizedCaseInsensitiveContains(searchText)
        }
        return base.reversed()
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "settings.loading_logs"))
            } else if filteredEntries.isEmpty {
                ContentUnavailableView(
                    entries.isEmpty ? "settings.no_logs" : "common.no_results",
                    systemImage: entries.isEmpty ? "doc.text" : "magnifyingglass",
                    description: Text(entries.isEmpty ? String(localized: "settings.nothing_has_been_logged_yet") : String(localized: "settings.no_logs_match_your_search"))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredEntries) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                    .padding()
                }
                .softScrollEdges()
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "settings.search_logs"))
        .navigationTitle("settings.logs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { loadEntries() }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu {
                    Button {
                        let text = entries.map { "[\($0.type)] \($0.message)" }.joined(separator: "\n")
                        #if os(iOS)
                        UIPasteboard.general.string = text
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        #endif
                    } label: {
                        Label("settings.copy_to_clipboard", icon: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        Task {
                            await Logger.shared.clearLogsAsync()
                            await MainActor.run { entries = [] }
                        }
                    } label: {
                        Label("settings.clear_logs", icon: "trash")
                    }
                } label: {
                    IconView("ellipsis.circle")
                }

                NavigationLink(destination: SettingsViewLoggerFilter(viewModel: filterViewModel)) {
                    IconView("slider.horizontal.3")
                }
            }
        }
    }

    private func loadEntries() {
        Task {
            let loaded = await Logger.shared.getLogEntriesAsync()
            await MainActor.run {
                self.entries = loaded
                self.isLoading = false
            }
        }
    }
}

struct SettingsViewLoggerFilter: View {
    @ObservedObject var viewModel = LogFilterViewModel.shared

    var body: some View {
        SettingsList {
            Section(header: Text("settings.log_types"), footer: Text("settings.choose_which_log_categories_to")) {
                ForEach($viewModel.filters) { $filter in
                    Toggle(isOn: $filter.isEnabled) {
                        Label {
                            Text(filter.type)
                        } icon: {
                            IconView(logTypeIcon(filter.type))
                                .foregroundStyle(logTypeColor(filter.type))
                        }
                    }
                    .tint(logTypeColor(filter.type))
                }
            }
        }
        .softScrollEdges()
        .navigationTitle("settings.log_filters")
    }
}

struct LogFilter: Identifiable, Hashable {
    let id = UUID()
    let type: String
    var isEnabled: Bool
    let description: String
}

class LogFilterViewModel: ObservableObject {
    nonisolated(unsafe) static let shared = LogFilterViewModel()
    
    @Published var filters: [LogFilter] = [] {
        didSet {
            saveFiltersToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "LogFilterStates"
    private let hardcodedFilters: [(type: String, description: String, defaultState: Bool)] = [
        ("General", String(localized: "settings.general_events_and_activities"), true),
        ("Stream", String(localized: "settings.streaming_and_video_playback"), true),
        ("Error", String(localized: "settings.errors_and_critical_issues"), true),
        ("Debug", String(localized: "settings.debugging_and_troubleshooting"), false),
        ("Network", String(localized: "settings.network_requests_and_responses"), false),
        ("Download", String(localized: "settings.hls_video_downloading"), true),
        ("HTMLStrings", String(localized: "settings.raw_html_response_strings"), false)
    ]
    
    private init() {
        loadFilters()
    }
    
    func loadFilters() {
        if let savedStates = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Bool] {
            filters = hardcodedFilters.map {
                LogFilter(
                    type: $0.type,
                    isEnabled: savedStates[$0.type] ?? $0.defaultState,
                    description: $0.description
                )
            }
        } else {
            filters = hardcodedFilters.map {
                LogFilter(type: $0.type, isEnabled: $0.defaultState, description: $0.description)
            }
        }
    }
    
    func toggleFilter(for type: String) {
        if let index = filters.firstIndex(where: { $0.type == type }) {
            filters[index].isEnabled.toggle()
        }
    }
    
    func isFilterEnabled(for type: String) -> Bool {
        return filters.first(where: { $0.type == type })?.isEnabled ?? true
    }
    
    private func saveFiltersToUserDefaults() {
        let states = filters.reduce(into: [String: Bool]()) { result, filter in
            result[filter.type] = filter.isEnabled
        }
        UserDefaults.standard.set(states, forKey: userDefaultsKey)
    }
}

class Logger: @unchecked Sendable {
    static let shared = Logger()

    struct LogEntry: Identifiable {
        let id = UUID()
        let message: String
        let type: String
        let timestamp: Date
    }
    
    private let queue = DispatchQueue(label: "com.shirox.logger", attributes: .concurrent)
    private var logs: [LogEntry] = []
    private let logFileURL: URL
    private let logFilterViewModel = LogFilterViewModel.shared

    private let maxFileSize = 1_024 * 512
    private let maxLogEntries = 1_000 
    
    private init() {
        logFileURL = AppDirectories.documents.appendingPathComponent("logs.txt")
    }
    
    /// Query/fragment keys whose values must never reach the log file.
    private static let sensitiveURLKeys: Set<String> = [
        "access_token", "refresh_token", "id_token", "token", "api_key", "apikey",
        "code", "client_secret", "password", "x-emby-token"
    ]

    /// Marker substituted for redacted values. Deliberately free of characters that URL
    /// serialization would percent-encode, so the marker stays readable in the log.
    static let redactionMarker = "REDACTED"

    /// URL rendered safe for the log file: sensitive query values and any fragment are replaced
    /// with `redactionMarker`. These logs are written to logs.txt and exported from Settings → App Logs,
    /// which is what users paste into bug reports — so a stream URL carrying a Jellyfin `api_key`,
    /// or an OAuth callback carrying `#access_token=…`, must not be written verbatim.
    static func redact(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "\(url.scheme ?? "?")://\(url.host ?? "?")/\(redactionMarker)"
        }
        if let items = comps.queryItems {
            comps.queryItems = items.map { item in
                sensitiveURLKeys.contains(item.name.lowercased())
                    ? URLQueryItem(name: item.name, value: redactionMarker)
                    : item
            }
        }
        if comps.fragment != nil { comps.fragment = redactionMarker }
        return comps.string ?? "\(url.scheme ?? "?")://\(url.host ?? "?")\(url.path)"
    }

    func log(_ message: String, type: String = "General") {
        guard logFilterViewModel.isFilterEnabled(for: type) else { return }
        
        let entry = LogEntry(message: message, type: type, timestamp: Date())
        
        queue.async(flags: .barrier) {
            self.logs.append(entry)
            
            if self.logs.count > self.maxLogEntries {
                self.logs.removeFirst(self.logs.count - self.maxLogEntries)
            }
            
            self.saveLogToFile(entry)
            self.debugLog(entry)
        }
    }
    
    func getLogs() -> String {
        var result = ""
        queue.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            result = logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type.uppercased())]\n\($0.message)" }
            .joined(separator: "\n\n" + String(repeating: "─", count: 20) + "\n\n")
        }
        return result
    }
    
    func getLogsAsync() async -> String {
        return await withCheckedContinuation { continuation in
            queue.async {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                let result = self.logs.map { "[\(dateFormatter.string(from: $0.timestamp))] [\($0.type.uppercased())]\n\($0.message)" }
                .joined(separator: "\n\n" + String(repeating: "─", count: 20) + "\n\n")
                continuation.resume(returning: result)
            }
        }
    }

    func getLogEntriesAsync() async -> [LogEntry] {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.logs)
            }
        }
    }
    
    func clearLogs() {
        queue.async(flags: .barrier) {
            self.logs.removeAll()
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
    }
    
    func clearLogsAsync() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.logs.removeAll()
                try? FileManager.default.removeItem(at: self.logFileURL)
                continuation.resume()
            }
        }
    }
    
    private func saveLogToFile(_ log: LogEntry) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        let separator = String(repeating: "─", count: 20)
        let logString = "[\(dateFormatter.string(from: log.timestamp))] [\(log.type.uppercased())]\n\(log.message)\n\(separator)\n"
        
        guard let data = logString.data(using: .utf8) else {
            return
        }
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                
                if fileSize + UInt64(data.count) > maxFileSize {
                    self.truncateLogFile()
                }
                
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try data.write(to: logFileURL)
            }
        } catch {
            try? data.write(to: logFileURL)
        }
    }
    
    private func truncateLogFile() {
        do {
            guard let content = try? String(contentsOf: logFileURL, encoding: .utf8),
                  !content.isEmpty else {
                return
            }
            
            let separator = String(repeating: "─", count: 20)
            let entries = content.components(separatedBy: "\n\(separator)\n")
            guard entries.count > 10 else { return }
            
            let keepCount = entries.count / 2
            let truncatedEntries = Array(entries.suffix(keepCount))
            let truncatedContent = truncatedEntries.joined(separator: "\n\(separator)\n")
            
            if let truncatedData = truncatedContent.data(using: .utf8) {
                try truncatedData.write(to: logFileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: logFileURL)
        }
    }
    
    private func debugLog(_ entry: LogEntry) {
#if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM HH:mm:ss"
        let formattedMessage = "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.type)] \(entry.message)"
        print(formattedMessage)
#endif
    }
}

#if !os(tvOS)
/// The Discord row under the providers, with the logo at the providers' icon size and rounding.
private struct DiscordSettingsRow: View {
    private var status: String {
        guard UserDefaults.standard.bool(forKey: DiscordPresence.enabledKey) else {
            return String(localized: "settings.off")
        }
        return DiscordPresence.shared.username ?? String(localized: "settings.discord_on")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image("DiscordLogo")
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            Text("settings.discord")
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
    }
}
#endif


/// Shows exactly what an overwrite or mirror would do before it does any of it. These runs can't be
/// undone, so the deletions are listed by name rather than just counted — a number is easy to
/// wave through, a list of titles you recognise is not.
private struct OverwritePreviewSheet: View {
    let run: SyncRun
    let plan: LibraryOverwritePlan
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var additions: Int { plan.writes.filter(\.isNew).count }
    private var overwrites: Int { plan.writes.filter { !$0.isNew }.count }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(run.title)
                        .font(.headline)
                    Text(run.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("settings.what_this_will_do") {
                    if plan.isEmpty {
                        Text("settings.nothing_already_matches \(run.targetName)")
                            .foregroundStyle(.secondary)
                    }
                    if additions > 0 { row(String(localized: "settings.add_to \(run.targetName)"), additions) }
                    if overwrites > 0 { row(String(localized: "settings.overwrite_on \(run.targetName)"), overwrites) }
                    if !plan.deletions.isEmpty {
                        row(String(localized: "settings.delete_from \(run.targetName)"), plan.deletions.count, tint: .red)
                    }
                    if plan.unchanged > 0 { row(String(localized: "settings.leave_unchanged"), plan.unchanged, tint: .secondary) }
                }

                if !plan.deletions.isEmpty {
                    Section("settings.will_be_deleted") {
                        ForEach(plan.deletions, id: \.id) { deletion in
                            Text(deletion.title)
                                .font(.callout)
                        }
                    }
                }

                if plan.keptUnverified > 0 || !plan.unmatched.isEmpty {
                    Section("settings.left_alone") {
                        if plan.keptUnverified > 0 {
                            Text("settings.on_couldnt_be_matched_against \(plan.keptUnverified) \(run.targetName) \(run.sourceName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !plan.unmatched.isEmpty {
                            Text("settings.on_have_no_entry_to \(plan.unmatched.count) \(run.sourceName) \(run.targetName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(run.confirmButtonTitle, role: .destructive, action: onConfirm)
                        .disabled(plan.isEmpty)
                } footer: {
                    Text("settings.this_cant_be_undone")
                }
            }
            .navigationTitle(run.confirmationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
            }
        }
    }

    private func row(_ label: String, _ count: Int, tint: Color = .primary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)")
                .foregroundStyle(tint)
        }
    }
}
