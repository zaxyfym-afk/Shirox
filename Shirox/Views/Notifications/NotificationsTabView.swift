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
    @State private var permission: UNAuthorizationStatus?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle("profile.notifications")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
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
