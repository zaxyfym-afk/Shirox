import AuthenticationServices
import SwiftUI
import UserNotifications

/// The Notifications tab: the tracker account's social feed beside the app's own episode
/// releases. The segments reuse what the Library's bell and Settings' page already had — the
/// feed wholesale, the followed list's rows — so the tab adds a door, not a second copy of
/// either.
struct NotificationsTabView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case activity, episodes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .activity: return String(localized: "notifications.activity")
            case .episodes: return String(localized: "notifications.episodes")
            }
        }
    }

    @State private var segment = Segment.activity
    @StateObject private var notificationsVM = ProfileViewModel()
    @ObservedObject private var store = FollowedSeriesStore.shared
    @ObservedObject private var notifier = EpisodeReleaseNotifier.shared
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    @State private var permission: UNAuthorizationStatus?
    #if os(iOS)
    @State private var presentationWindow: UIWindow?
    #endif

    /// How many of the two trackers are connected; the tab's first screen is a connection
    /// interface when the answer is none.
    private var connectedCount: Int {
        [aniListAuth.isLoggedIn, malAuth.isLoggedIn].filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            if connectedCount == 0 {
                NotificationsConnectView()
            } else {
                VStack(spacing: 0) {
                    if connectedCount == 1 {
                        secondConnectionBanner
                    }
                    Picker("profile.notifications", selection: $segment) {
                        ForEach(Segment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    switch segment {
                    case .activity: NotificationsView(vm: notificationsVM)
                    case .episodes: episodesSegment
                    }
                }
            }
        }
        .navigationTitle("profile.notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
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

    /// One tracker connected, one not: a slim invitation, never a block.
    @ViewBuilder
    private var secondConnectionBanner: some View {
        let connected = aniListAuth.isLoggedIn ? "AniList" : "MyAnimeList"
        let other = aniListAuth.isLoggedIn ? "MyAnimeList" : "AniList"
        HStack(spacing: 10) {
            IconView("personalhotspot")
                .font(.body)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("notifications.one_more_thing \(connected) \(other)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                signIn(aniListAuth.isLoggedIn ? .mal : .anilist)
            } label: {
                Text("notifications.connect_second \(other)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    // MARK: - Episodes

    private var episodesSegment: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if showsPermissionCard {
                    permissionCard
                }

                let entries = upcomingFirst
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        IconView("bell.slash")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("notifications.no_followed_series_hint")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(entries) { entry in
                        NavigationLink {
                            MediaDestination(media: entry.media)
                        } label: {
                            episodeRow(entry)
                        }
                        .buttonStyle(.plain)
                        .modifier(UnfollowSwipe(entry: entry, unfollow: unfollow))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .softScrollEdges()
        .circleRefreshable { await checkNow() }
        .task { await refreshPermission() }
    }

    /// The followed series, soonest broadcast first; the ones with nothing scheduled keep
    /// their place by name.
    private var upcomingFirst: [FollowedSeries] {
        store.series.sorted { a, b in
            switch (a.nextAiringAt, b.nextAiringAt) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
        }
    }

    private func episodeRow(_ entry: FollowedSeries) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(urlString: entry.coverURL ?? "")
                .frame(width: 44, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                CardTitle(entry.title)
                    .font(.subheadline.weight(.medium))
                nextLine(entry)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.07)))
    }

    /// "EP 7 · Fri, Nov 21 at 9:00 PM", or nothing scheduled.
    @ViewBuilder
    private func nextLine(_ entry: FollowedSeries) -> some View {
        if let episode = entry.nextEpisode, let date = entry.nextAiringAt {
            HStack(spacing: 6) {
                Text("notifications.ep \(episode)")
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Text("notifications.no_scheduled_episode")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func unfollow(_ entry: FollowedSeries) {
        store.remove(id: entry.id)
        Task { await notifier.cancel(seriesID: entry.id) }
    }

    // MARK: - Permission

    /// The card asks only when there's something to notify about: with no follows, the empty
    /// state's hint is the more useful thing on screen.
    private var showsPermissionCard: Bool {
        guard !store.series.isEmpty else { return false }
        switch permission {
        case .authorized, .provisional, .ephemeral: return false
        default: return true
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 14) {
            IconView("bell.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor))
                .overlay(alignment: .topTrailing) {
                    Circle().fill(Color.red).frame(width: 10, height: 10).offset(x: 3, y: -3)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("notifications.turn_on_notifications")
                    .font(.subheadline.weight(.semibold))
                Text("notifications.turn_on_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                if permission == .denied {
                    openSystemSettings()
                } else {
                    Task {
                        _ = await notifier.requestPermissionIfNeeded()
                        await refreshPermission()
                    }
                }
            } label: {
                Text(permission == .denied ? String(localized: "notifications.open_system_settings")
                                           : String(localized: "notifications.turn_on"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.07)))
    }

    private func refreshPermission() async {
        permission = await notifier.authorizationStatus
    }

    private func checkNow() async {
        await notifier.checkNow(force: true)
        await refreshPermission()
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - Signed-out connection interface

/// The Notifications tab with no tracker connected: a purpose-built connection screen, not a
/// recycled empty state. White and grey, one card per service, each with its own connect
/// action; the tab switches to the feed the moment the first connection lands.
struct NotificationsConnectView: View {
    @Environment(\.horizontalSizeClass) private var hClass
    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared
    #if os(iOS)
    @State private var presentationWindow: UIWindow?
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 96, height: 96)
                    IconView("bell")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("notifications.connect_title")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("notifications.connect_hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                serviceCards
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .softScrollEdges()
        #if os(iOS)
        .onAppear {
            presentationWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        #endif
    }

    /// The two services side by side when there is room, stacked when there isn't.
    @ViewBuilder
    private var serviceCards: some View {
        if hClass == .regular {
            HStack(spacing: 14) {
                serviceCard(.anilist)
                serviceCard(.mal)
            }
        } else {
            VStack(spacing: 14) {
                serviceCard(.anilist)
                serviceCard(.mal)
            }
        }
    }

    /// One service: its icon and name, one connect action. While the web session runs the
    /// button sits disabled; the parent view takes over the moment `isLoggedIn` flips.
    private func serviceCard(_ type: ProviderType) -> some View {
        let isLoggedIn = type == .anilist ? aniListAuth.isLoggedIn : malAuth.isLoggedIn
        let username = type == .anilist ? aniListAuth.username : malAuth.username
        return VStack(spacing: 12) {
            CachedAsyncImage(urlString: type.iconURL)
                .frame(width: 44, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .accessibilityHidden(true)

            Text(type.displayName)
                .font(.headline)

            if isLoggedIn {
                Label(username.map { "notifications.connected_as \($0)" } ?? "settings.signed_in",
                      icon: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    signIn(type)
                } label: {
                    Text(type == .anilist ? "notifications.connect_anilist" : "notifications.connect_mal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
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
}
