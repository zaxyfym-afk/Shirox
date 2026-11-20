import Foundation

struct AniListMedia: Identifiable, Codable {
    let id: Int
    let idMal: Int?
    let title: AniListTitle
    let coverImage: AniListCoverImage
    let bannerImage: String?
    let description: String?
    let episodes: Int?
    let chapters: Int?        // manga total; nil for anime or ongoing manga
    let status: String?
    let averageScore: Int?
    let genres: [String]?
    let season: String?
    let seasonYear: Int?
    let nextAiringEpisode: AniListAiringEpisode?
    let relations: AniListRelations?
    let type: String?
    let format: String?
    /// Minutes per episode. New with the detailed-airing detail query; nil in older payloads.
    var duration: Int?
    /// First and last broadcast, as far as AniList knows either.
    var startDate: AniListFuzzyDate?
    var endDate: AniListFuzzyDate?
    /// AniList's community tags, ranked; the spoiler flag keeps the spoilery ones out of view.
    var tags: [AniListTag]?
    /// The main studio, from `studios(isMain: true)`.
    var studios: AniListStudioConnection?
    /// Users' recommendations for this title — the detail page's "More Like This".
    var recommendations: AniListRecommendationConnection?

    init(id: Int, idMal: Int? = nil, title: AniListTitle, coverImage: AniListCoverImage,
         bannerImage: String? = nil, description: String? = nil, episodes: Int? = nil,
         chapters: Int? = nil, status: String? = nil, averageScore: Int? = nil,
         genres: [String]? = nil, season: String? = nil, seasonYear: Int? = nil,
         nextAiringEpisode: AniListAiringEpisode? = nil, relations: AniListRelations? = nil,
         type: String? = nil, format: String? = nil, duration: Int? = nil,
         startDate: AniListFuzzyDate? = nil, endDate: AniListFuzzyDate? = nil,
         tags: [AniListTag]? = nil, studios: AniListStudioConnection? = nil,
         recommendations: AniListRecommendationConnection? = nil) {
        self.id = id
        self.idMal = idMal
        self.title = title
        self.coverImage = coverImage
        self.bannerImage = bannerImage
        self.description = description
        self.episodes = episodes
        self.chapters = chapters
        self.status = status
        self.averageScore = averageScore
        self.genres = genres
        self.season = season
        self.seasonYear = seasonYear
        self.nextAiringEpisode = nextAiringEpisode
        self.relations = relations
        self.type = type
        self.format = format
        self.duration = duration
        self.startDate = startDate
        self.endDate = endDate
        self.tags = tags
        self.studios = studios
        self.recommendations = recommendations
    }

    /// The recommended titles, without the GraphQL connection wrapper.
    var recommendationList: [AniListMedia] {
        (recommendations?.nodes ?? []).compactMap(\.mediaRecommendation)
    }

    /// The main studio's name, when AniList lists one.
    var mainStudioName: String? { studios?.nodes?.first?.name }

    var plainDescription: String? {
        guard let desc = description else { return nil }
        return desc
            .replacingOccurrences(of: "<br><br>", with: "\n\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var statusDisplay: String? {
        switch status {
        case "RELEASING": return String(localized: "shared.airing")
        case "FINISHED": return String(localized: "shared.finished")
        case "NOT_YET_RELEASED": return String(localized: "shared.upcoming")
        case "CANCELLED": return String(localized: "shared.cancelled")
        case "HIATUS": return String(localized: "shared.hiatus")
        default: return status
        }
    }
}

struct AniListTitle: Codable {
    let romaji: String?
    let english: String?
    let native: String?

    var displayTitle: String {
        let priority = UserDefaults.standard.string(forKey: "titleLanguagePriority") ?? "english,romaji,native"
        let ordered = priority.components(separatedBy: ",")
        for lang in ordered {
            switch lang {
            case "english": if let e = english, !e.isEmpty { return e }
            case "romaji":  if let r = romaji, !r.isEmpty { return r }
            case "native":  if let n = native, !n.isEmpty { return n }
            default: break
            }
        }
        return english ?? romaji ?? native ?? String(localized: "shared.unknown")
    }

    var searchTitle: String {
        let priority = UserDefaults.standard.string(forKey: "titleLanguagePriority") ?? "english,romaji,native"
        let ordered = priority.components(separatedBy: ",")
        for lang in ordered {
            switch lang {
            case "english": if let e = english, !e.isEmpty { return e }
            case "romaji":  if let r = romaji, !r.isEmpty { return r }
            case "native":  if let n = native, !n.isEmpty { return n }
            default: break
            }
        }
        return romaji ?? english ?? native ?? ""
    }
}

struct AniListCoverImage: Codable {
    let large: String?
    let extraLarge: String?

    var best: String? { extraLarge ?? large }
}

struct AniListAiringEpisode: Codable {
    let episode: Int
    /// Unix seconds of the broadcast. Not part of older queries' payloads, so it decodes
    /// as nil from every response that didn't ask for it.
    var airingAt: Int?
    /// Seconds until the broadcast, AniList's own countdown field.
    var timeUntilAiring: Int?
}

/// AniList's partial dates: a year, maybe a month, maybe a day.
struct AniListFuzzyDate: Codable, Hashable {
    var year: Int?
    var month: Int?
    var day: Int?

    /// Nil until there's at least a year to show.
    var display: String? {
        guard let year else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = Calendar.current.date(from: components) else { return String(year) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

/// One of AniList's community tags for a title.
struct AniListTag: Codable, Hashable {
    var name: String
    var rank: Int?
    var isGeneralSpoiler: Bool?
    var isSpoiler: Bool { isGeneralSpoiler == true }
}

struct AniListStudio: Codable, Hashable {
    var name: String
}

struct AniListStudioConnection: Codable, Hashable {
    var nodes: [AniListStudio]?
}

/// The recommendation connection: `nodes { mediaRecommendation { ... } }`.
struct AniListRecommendationConnection: Codable {
    var nodes: [AniListRecommendation]?
}

struct AniListRecommendation: Codable {
    var mediaRecommendation: AniListMedia?
}

enum AniListSeason: String {
    case winter = "WINTER"
    case spring = "SPRING"
    case summer = "SUMMER"
    case fall = "FALL"

    static func current() -> (AniListSeason, Int) {
        let month = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        let season: AniListSeason
        switch month {
        case 1...3: season = .winter
        case 4...6: season = .spring
        case 7...9: season = .summer
        default: season = .fall
        }
        return (season, year)
    }

    /// The season immediately before `from` (defaults to now).
    ///
    /// Used for the "Last Season" home row: by the time a cour ends, the shows people most
    /// want to binge are the ones that just finished, and "This Season" no longer lists them.
    /// Winter rolls back into the previous calendar year's Fall.
    static func previous(from reference: Date = Date()) -> (AniListSeason, Int) {
        let month = Calendar.current.component(.month, from: reference)
        let year = Calendar.current.component(.year, from: reference)
        switch month {
        case 1...3:  return (.fall, year - 1)
        case 4...6:  return (.winter, year)
        case 7...9:  return (.spring, year)
        default:     return (.summer, year)
        }
    }
}

struct AniListRelations: Codable {
    let edges: [AniListRelationEdge]
}

struct AniListRelationEdge: Codable, Identifiable {
    var id: Int { node.id }
    let relationType: String
    let node: AniListMedia

    var formattedRelation: String {
        relationType.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
