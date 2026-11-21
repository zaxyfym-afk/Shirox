import SwiftUI
import UserNotifications

/// Settings ▸ Notifications: new-episode notifications for followed series.
///
/// Deliberately separate from the tracker accounts' social notifications (the Library's
/// bell): this page is only about episodes airing, from the app's own follow list.
///
/// The layout is built around what a notification page actually needs to answer: will the
/// system deliver (the delivery card's big state), when to check (the sweep row), and what
/// is being watched (the next-up board — the followed series as poster cards with their
/// next airing, not list rows).
struct NotificationsSettingsView: View {
    @ObservedObject private var store = FollowedSeriesStore.shared
    @ObservedObject private var notifier = EpisodeReleaseNotifier.shared
    @AppStorage(EpisodeReleaseNotifier.enabledKey) private var enabled = true
    @State private var permission: UNAuthorizationStatus?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                deliveryCard
                checkRow
                followedBoard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("settings.notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await refreshPermission() }
        .onChangeOf(enabled) { on in
            Task { await handleToggle(on) }
        }
    }

    // MARK: Delivery

    /// Whether notifications arrive at all, in one card: the bell's state, the master
    /// switch beside it, and — only when something is actually blocking — the fix.
    private var deliveryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 52, height: 52)
                    IconView(deliverySymbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(deliveryTint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("notifications.notify_new_episodes")
                        .font(.body.weight(.semibold))
                    Text(permissionLabel)
                        .font(.caption)
                        .foregroundStyle(deliveryTint)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .switchTint()
            }

            if permission == .denied {
                Button {
                    openSystemSettings()
                } label: {
                    Label("notifications.open_system_settings", icon: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var deliverySymbol: String {
        guard enabled else { return "bell.slash" }
        switch permission {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "exclamationmark.bubble"
        default: return "bell"
        }
    }

    private var deliveryTint: Color {
        if permission == .denied && enabled { return .orange }
        return .secondary
    }

    // MARK: Check

    /// One manual sweep: a full-width action with when it last ran and what it found.
    private var checkRow: some View {
        Button {
            Task { await checkNow() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 36, height: 36)
                    if notifier.isChecking {
                        ProgressView()
                    } else {
                        IconView("arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("notifications.check_now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(lastCheckLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(store.series.isEmpty || !enabled || notifier.isChecking)
        .opacity(store.series.isEmpty || !enabled ? 0.55 : 1)
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

    private var permissionLabel: String {
        if !enabled { return String(localized: "notifications.turn_off_hint") }
        switch permission {
        case .authorized, .provisional, .ephemeral: return String(localized: "notifications.permission_granted")
        case .denied: return String(localized: "notifications.permission_denied")
        default: return String(localized: "notifications.permission_not_asked")
        }
    }

    private var lastCheckLine: String {
        if store.series.isEmpty { return String(localized: "notifications.no_followed_series") }
        if notifier.lastCheckNewEpisodes > 0 {
            return String(localized: "notifications.found_new_episodes \(notifier.lastCheckNewEpisodes)")
        }
        return String(localized: "notifications.up_to_date")
    }

    // MARK: Next up

    /// The followed series as a board of poster cards, soonest airing first — what the
    /// notifications are actually about. Empty is one honest line.
    @ViewBuilder
    private var followedBoard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("notifications.followed_series")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if store.series.isEmpty {
                VStack(spacing: 10) {
                    IconView("bell.slash")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("notifications.no_followed_series_hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(upcomingFirst) { entry in
                        NavigationLink {
                            MediaDestination(media: entry.media)
                        } label: {
                            followedCard(entry)
                        }
                        .buttonStyle(.plain)
                        .modifier(UnfollowSwipe(entry: entry, unfollow: unfollow))
                    }
                }
            }
        }
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

    /// One card: the poster, the title over it, and the next airing as a chip. Long-press
    /// offers unfollow where swipe isn't available.
    private func followedCard(_ entry: FollowedSeries) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(urlString: entry.coverURL ?? "") { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.primary.opacity(0.06))
            }
            .frame(height: 128)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if let episode = entry.nextEpisode {
                    Text("notifications.ep \(episode)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
                .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 2) {
                CardTitle(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(nextDateLine(entry))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                unfollow(entry)
            } label: {
                Label("notifications.unfollow", icon: "bell.slash")
            }
        }
    }

    /// The card's date line: weekday and time when something airs, else nothing scheduled.
    private func nextDateLine(_ entry: FollowedSeries) -> String {
        guard let date = entry.nextAiringAt else {
            return String(localized: "notifications.no_scheduled_episode")
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    private func unfollow(_ entry: FollowedSeries) {
        store.remove(id: entry.id)
        Task { await notifier.cancel(seriesID: entry.id) }
    }

    // MARK: Helpers

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
