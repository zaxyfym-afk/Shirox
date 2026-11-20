import Combine
import Foundation

/// A title the user follows for release notifications, in the app's own store — deliberately
/// kept apart from the tracker accounts' social notifications.
struct FollowedSeries: Codable, Identifiable, Equatable, Hashable {
    /// `"<provider>-<id>"`, the id the title was followed on.
    var id: String { "\(provider.rawValue)-\(mediaID)" }
    let mediaID: Int
    let provider: ProviderType
    /// The AniList id when one is known, and the MyAnimeList id when one is — the aired-count
    /// check can use either.
    var anilistID: Int?
    var malID: Int?
    let title: String
    let coverURL: String?
    /// Aired episodes at the last check; nil until then, so nothing is "new" on first sight.
    var lastAired: Int?
    /// The next broadcast, as AniList last reported it.
    var nextEpisode: Int?
    var nextAiringAt: Date?
    var lastChecked: Date?

    /// From any anime `Media`: the ids the check will use, whatever page it was followed on.
    init(media: Media) {
        mediaID = media.id
        provider = media.provider == .mal ? .mal : .anilist
        anilistID = media.provider == .anilist ? media.id : media.idMal
        malID = media.provider == .mal ? media.id : media.idMal
        title = media.title.displayTitle
        coverURL = media.coverImage.best
        lastAired = media.nextAiringEpisode.map { max($0.episode - 1, 0) }
        nextEpisode = media.nextAiringEpisode?.episode
        nextAiringAt = media.nextAiringEpisode?.airingAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        lastChecked = nil
    }

    /// A minimal `Media` standing in for the followed title: enough for a row's navigation,
    /// and the page it opens refetches everything.
    var media: Media {
        Media(
            id: provider == .mal ? mediaID : (anilistID ?? mediaID),
            idMal: malID,
            provider: provider,
            title: MediaTitle(romaji: nil, english: title, native: nil),
            coverImage: MediaCoverImage(large: coverURL, extraLarge: coverURL),
            bannerImage: nil, description: nil, episodes: nil,
            status: nil, averageScore: nil, genres: nil,
            season: nil, seasonYear: nil, nextAiringEpisode: nil,
            relations: nil, type: nil, format: nil
        )
    }
}

/// The followed series on this profile: what the release notifier checks and what the
/// Notifications page lists. Kept as JSON in one UserDefaults key, so it travels with a
/// backup and swaps with the profile.
@MainActor
final class FollowedSeriesStore: ObservableObject {
    static let shared = FollowedSeriesStore()

    static let storageKey = "followedSeries"

    @Published private(set) var series: [FollowedSeries] {
        didSet { persist() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([FollowedSeries].self, from: data) {
            series = decoded
        } else {
            series = []
        }
    }

    /// After a profile switch: the new profile's follows, and nothing of the last one's.
    func reloadForProfileSwitch() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([FollowedSeries].self, from: data) {
            series = decoded
        } else {
            series = []
        }
    }

    func isFollowing(_ media: Media) -> Bool {
        series.contains { $0.id == FollowedSeries(media: media).id }
    }

    /// Follows or unfollows; true when the title is followed afterwards.
    @discardableResult
    func toggle(_ media: Media) -> Bool {
        let followed = FollowedSeries(media: media)
        if let index = series.firstIndex(where: { $0.id == followed.id }) {
            series.remove(at: index)
            return false
        }
        series.append(followed)
        return true
    }

    /// Replaces one entry in place, keeping the followed order.
    func update(_ entry: FollowedSeries) {
        guard let index = series.firstIndex(where: { $0.id == entry.id }) else { return }
        series[index] = entry
    }

    func remove(id: String) {
        series.removeAll { $0.id == id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(series) {
            UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: Self.storageKey)
        }
    }
}
