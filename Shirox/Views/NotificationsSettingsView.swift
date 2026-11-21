import SwiftUI
import UserNotifications

/// Settings ▸ Notifications: new-episode notifications for followed series.
///
/// Deliberately separate from the tracker accounts' social notifications (the Library's
/// bell): this page is only about episodes airing, from the app's own follow list.
struct NotificationsSettingsView: View {
    @ObservedObject private var store = FollowedSeriesStore.shared
    @ObservedObject private var notifier = EpisodeReleaseNotifier.shared
    @AppStorage(EpisodeReleaseNotifier.enabledKey) private var enabled = true
    @State private var permission: UNAuthorizationStatus?

    var body: some View {
        SettingsList(tint: .red, heroIcon: "bell", heroTitle: "settings.notifications", heroSubtitle: "settings.notifications_hero_sub") {
            Section {
                Toggle("notifications.notify_new_episodes", isOn: $enabled)
                    .switchTint()
                Text("notifications.notify_new_episodes_footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                SettingsSectionHeader(icon: "play.rectangle.on.rectangle", title: "notifications.new_episodes")
            }

            permissionSection

            Section {
                Button {
                    Task { await checkNow() }
                } label: {
                    HStack {
                        Text("notifications.check_now")
                        Spacer()
                        if notifier.isChecking { ProgressView() }
                    }
                }
                .disabled(store.series.isEmpty || !enabled)

                if !notifier.isChecking {
                    Text(lastCheckLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("notifications.check_now_footer")
            }

            followedSection
        }
        .softScrollEdges()
        .navigationTitle("settings.notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await refreshPermission() }
        .onChangeOf(enabled) { on in
            Task { await handleToggle(on) }
        }
    }

    // MARK: - Permission

    /// The system's answer to showing notifications at all; nil until asked.
    private var permissionSection: some View {
        Section {
            HStack {
                Label(permissionLabel, icon: permissionIcon)
                Spacer()
                if permission == .denied {
                    Button("notifications.open_system_settings") { openSystemSettings() }
                        .font(.caption)
                }
            }
            if permission == .denied {
                Text("notifications.denied_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            SettingsSectionHeader(icon: "bell.fill", title: "notifications.permission")
        }
    }

    private var permissionLabel: String {
        switch permission {
        case .authorized, .provisional, .ephemeral: return String(localized: "notifications.permission_granted")
        case .denied: return String(localized: "notifications.permission_denied")
        default: return String(localized: "notifications.permission_not_asked")
        }
    }

    private var permissionIcon: String {
        switch permission {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle"
        case .denied: return "exclamationmark.circle"
        default: return "questionmark.circle"
        }
    }

    private func refreshPermission() async {
        permission = await notifier.authorizationStatus
    }

    private func handleToggle(_ on: Bool) async {
        if on {
            _ = await notifier.requestPermissionIfNeeded()
            await refreshPermission()
            await checkNow()
        } else {
            await notifier.removeAllScheduled()
        }
    }

    private func checkNow() async {
        await notifier.checkNow(force: true)
        await refreshPermission()
    }

    private var lastCheckLine: String {
        if store.series.isEmpty { return String(localized: "notifications.no_followed_series") }
        if notifier.lastCheckNewEpisodes > 0 {
            return String(localized: "notifications.found_new_episodes \(notifier.lastCheckNewEpisodes)")
        }
        return String(localized: "notifications.up_to_date")
    }

    // MARK: - Followed series

    @ViewBuilder
    private var followedSection: some View {
        Section {
            if store.series.isEmpty {
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
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.series) { entry in
                    NavigationLink {
                        MediaDestination(media: entry.media)
                    } label: {
                        followedRow(entry)
                    }
                    .modifier(UnfollowSwipe(entry: entry, unfollow: unfollow))
                }
            }
        } header: {
            SettingsSectionHeader(icon: "heart.text.square", title: "notifications.followed_series")
        } footer: {
            if !store.series.isEmpty {
                Text("notifications.followed_footer")
            }
        }
    }

    private func followedRow(_ entry: FollowedSeries) -> some View {
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
        .padding(.vertical, 2)
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

    // MARK: - Helpers

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

/// Swipe-to-unfollow where the platform has swipe actions (iOS, Catalyst); a context menu
/// everywhere else. Shared with the Notifications tab's episode list.
struct UnfollowSwipe: ViewModifier {
    let entry: FollowedSeries
    let unfollow: (FollowedSeries) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.swipeActions(edge: .trailing) {
            Button(role: .destructive) { unfollow(entry) } label: {
                Label("notifications.unfollow", icon: "bell.slash")
            }
        }
        #else
        content.contextMenu {
            Button(role: .destructive) { unfollow(entry) } label: {
                Label("notifications.unfollow", icon: "bell.slash")
            }
        }
        #endif
    }
}
