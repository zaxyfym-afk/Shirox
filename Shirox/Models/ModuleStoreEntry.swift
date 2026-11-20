import Foundation

// MARK: - Catalog

/// The Module Store's catalog: the categories it shelves and the entries in them. A JSON
/// document, fetched from a configurable URL with a bundled placeholder as the starting
/// content — the store opens empty and fills when a real catalog arrives.
struct ModuleStoreCatalog: Codable, Equatable {
    var categories: [ModuleStoreCategory]
    var entries: [ModuleStoreEntry]

    static let empty = ModuleStoreCatalog(categories: [], entries: [])
}

/// One shelf of the store. The three built-in ids localize; anything a real catalog brings
/// names itself.
struct ModuleStoreCategory: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let kind: ModuleStoreEntry.Kind

    var displayName: String {
        switch id {
        case "video":   return String(localized: "store.video")
        case "manga":   return String(localized: "store.manga")
        case "utility": return String(localized: "store.utility")
        default:        return name
        }
    }
}

// MARK: - Entry

/// One installable in the store. `manifestURL` is the whole install story: it's the link the
/// existing `ModuleManager.addModule(from:)` already understands, whatever ecosystem the
/// manifest belongs to.
struct ModuleStoreEntry: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let description: String
    /// The category (shelf) id this entry sits in.
    let category: String
    let author: String?
    let version: String
    let iconURL: String?
    let manifestURL: String
    let kind: Kind
    /// Chosen for the store's header; absent means an ordinary shelf entry.
    let featured: Bool?
    /// Rendered by the detail sheet when a real catalog brings them.
    let screenshots: [String]?
    /// The first Shirox version that can run it; absent means any.
    let minAppVersion: String?

    enum Kind: String, Codable { case video, manga, utility }
}

// MARK: - Version comparison

extension String {
    /// Dot-separated versions, ordered: "1.2" < "1.10" < "2.0". Anything unparsable sorts by
    /// plain string compare, which is still a stable order.
    func isStoreVersion(atLeast other: String) -> Bool {
        let mine = storeVersionParts
        let theirs = other.storeVersionParts
        for (a, b) in zip(mine, theirs) where a != b { return a > b }
        return mine.count >= theirs.count || mine == theirs
    }

    private var storeVersionParts: [Int] {
        split(separator: ".").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}
