import Combine
import Foundation
import UserNotifications

/// The next broadcast of one anime, as AniList reports it.
struct AniListNextAiring: Equatable {
    let episode: Int
    /// When it airs, local to the user's clock.
    let airingAt: Date
}

/// Watches the followed series for new episodes and notifies about them:
///
/// - A local notification is scheduled at the next episode's air time, so it arrives even
///   with the app closed (iOS delivers scheduled notifications itself).
/// - On the foreground, and from Settings, `checkNow` refreshes what has aired, banners what
///   the user hasn't heard about yet, and re-schedules the next broadcast.
///
/// Everything runs through AniList's public airing schedule — no account needed for the
/// check, and nothing is invented: no data, no notification.
@MainActor
final class EpisodeReleaseNotifier: ObservableObject {
    static let shared = EpisodeReleaseNotifier()

    static let enabledKey = "episodeNotificationsEnabled"
    private static let lastCheckKey = "episodeNotificationsLastCheck"
    /// The foreground check hits AniList at most this often.
    private static let minInterval: TimeInterval = 15 * 60
    /// So a returning user isn't buried after two weeks away.
    private static let maxBannersPerCheck = 4
    /// How far ahead a notification may be scheduled; iOS keeps at most 64 pending ones.
    private static let maxScheduleAhead: TimeInterval = 14 * 24 * 60 * 60

    /// Whether a check is running, so Settings can show it.
    @Published private(set) var isChecking = false
    /// How many new-episode banners the last check posted, for Settings to report.
    @Published private(set) var lastCheckNewEpisodes = 0

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { Task { await removeAllScheduled() } }
        }
    }

    // MARK: - Permission

    /// The system's answer, without asking. `.notDetermined` until the first request.
    var authorizationStatus: UNAuthorizationStatus {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    /// Asks when the user follows their first series or turns the toggle on; true when
    /// notifications may be shown either way.
    func requestPermissionIfNeeded() async -> Bool {
        switch await authorizationStatus {
        case .notDetermined:
            return (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        @unknown default:
            return false
        }
    }

    // MARK: - Checking

    /// Refreshes every followed series: what's aired, what's next, which notifications to
    /// post and which to schedule. Errors are swallowed on purpose — a check that can't
    /// reach AniList leaves everything as it was and tries again next time.
    func checkNow(force: Bool = false) async {
        let store = FollowedSeriesStore.shared
        guard isEnabled, !store.series.isEmpty, !isChecking else { return }
        if !force, let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Double,
           Date().timeIntervalSince(Date(timeIntervalSince1970: last)) < Self.minInterval { return }
        isChecking = true
        defer { isChecking = false }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

        let anilistIDs = Array(Set(store.series.compactMap(\.anilistID)))
        let malIDs = Array(Set(store.series.compactMap(\.malID)))
        let next = await AniListService.shared.nextAiring(aniListIDs: anilistIDs, malIDs: malIDs)
        let counts = await AniListService.shared.airedEpisodes(aniListIDs: anilistIDs, malIDs: malIDs)

        let mayShow = await requestPermissionIfNeeded()
        var banners = 0
        let now = Date()
        for followed in store.series {
            var entry = followed
            entry.lastChecked = now
            if let anilist = entry.anilistID {
                entry.nextEpisode = next.byAniList[anilist]?.episode ?? entry.nextEpisode
                entry.nextAiringAt = next.byAniList[anilist]?.airingAt ?? entry.nextAiringAt
            }
            if let mal = entry.malID {
                entry.nextEpisode = next.byMal[mal]?.episode ?? entry.nextEpisode
                entry.nextAiringAt = next.byMal[mal]?.airingAt ?? entry.nextAiringAt
            }
            let aired = entry.anilistID.flatMap { counts.byAniList[$0] } ?? entry.malID.flatMap { counts.byMal[$0] }
            if let aired { entry.lastAired = aired }
            store.update(entry)
            await schedule(entry)

            // Only what aired since the last check is news; the first check just learns
            // where things stand.
            if mayShow, let aired, let last = followed.lastAired, aired > last, banners < Self.maxBannersPerCheck {
                banners += 1
                await postBanner(entry: entry, aired: aired, previous: last)
            }
        }
        lastCheckNewEpisodes = banners
    }

    /// Removes a series' scheduled notification; called when it's unfollowed.
    func cancel(seriesID: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.scheduleID(for: seriesID)])
    }

    func removeAllScheduled() async {
        let ids = FollowedSeriesStore.shared.series.map { Self.scheduleID(for: $0.id) }
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Notifications

    private static func scheduleID(for seriesID: String) -> String { "episode-release-\(seriesID)" }

    /// One notification per series, at its next episode's air time.
    private func schedule(_ entry: FollowedSeries) async {
        let center = UNUserNotificationCenter.current()
        let id = Self.scheduleID(for: entry.id)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard isEnabled, await requestPermissionIfNeeded(),
              let episode = entry.nextEpisode, let airingAt = entry.nextAiringAt,
              airingAt > Date(), airingAt < Date().addingTimeInterval(Self.maxScheduleAhead)
        else { return }
        let content = UNMutableNotificationContent()
        content.title = entry.title
        content.body = String(localized: "notifications.episode_is_out \(episode)")
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: airingAt)
        components.calendar = .current
        components.timeZone = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func postBanner(entry: FollowedSeries, aired: Int, previous: Int) async {
        let content = UNMutableNotificationContent()
        content.title = entry.title
        if aired - previous > 1 {
            content.body = String(localized: "notifications.new_episodes_out \(aired - previous)")
        } else {
            content.body = String(localized: "notifications.episode_is_out \(aired)")
        }
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "episode-new-\(entry.id)-\(aired)", content: content, trigger: nil))
    }
}
