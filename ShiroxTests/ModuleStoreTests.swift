import XCTest
@testable import Shirox

/// The Module Store's own logic: the bundled catalog, the shelves and search, and the
/// mapping between an entry and the modules installed. Installing itself is the module
/// manager's, already tested on its own.
@MainActor
final class ModuleStoreTests: XCTestCase {
    private var store: ModuleStoreService { .shared }

    private func entry(id: String, name: String = "Example", version: String = "1.0",
                       manifest: String = "https://example.com/module.json") -> ModuleStoreEntry {
        ModuleStoreEntry(
            id: id, name: name, tagline: "A test entry", description: "Longer text",
            category: "video", author: "Someone", version: version, iconURL: nil,
            manifestURL: manifest, kind: .video, featured: nil,
            screenshots: nil, minAppVersion: nil
        )
    }

    // MARK: - Catalog

    func testTheBundledCatalogDecodes() throws {
        let catalog = try XCTUnwrap(ModuleStoreService.bundledCatalog())
        XCTAssertEqual(catalog.entries, [], "The placeholder carries no modules")
        XCTAssertEqual(catalog.categories.map(\.id), ["video", "manga", "utility"])
        XCTAssertEqual(catalog.categories.map(\.kind),
                       [.video, .manga, .utility])
    }

    func testTheBuiltInCategoriesLocalize() {
        let video = ModuleStoreCategory(id: "video", name: "Video", kind: .video)
        XCTAssertEqual(video.displayName, String(localized: "store.video"))
        // A category a real catalog brings names itself.
        let other = ModuleStoreCategory(id: "music", name: "Music videos", kind: .video)
        XCTAssertEqual(other.displayName, "Music videos")
    }

    // MARK: - Shelves and search

    func testAShelfHoldsOnlyItsEntriesAndSearchCutsAcrossShelves() {
        let catalog = ModuleStoreCatalog(
            categories: [ModuleStoreCategory(id: "video", name: "Video", kind: .video)],
            entries: [
                entry(id: "a", name: "Alpha", manifest: "https://example.com/a.json"),
                ModuleStoreEntry(id: "b", name: "Beta", tagline: "Manga reader", description: "",
                                 category: "manga", author: nil, version: "1.0", iconURL: nil,
                                 manifestURL: "https://example.com/b.json", kind: .manga,
                                 featured: true, screenshots: nil, minAppVersion: nil)
            ])
        store.adopt(catalog)

        let video = ModuleStoreCategory(id: "video", name: "Video", kind: .video)
        XCTAssertEqual(store.entries(in: video).map(\.id), ["a"])
        XCTAssertEqual(store.featured().map(\.id), ["b"])
        XCTAssertEqual(store.allEntries(matching: "manga").map(\.id), ["b"], "Taglines are searched too")
        XCTAssertEqual(store.allEntries(matching: "").count, 2)
        XCTAssertEqual(store.allEntries(matching: "nothing").count, 0)
    }

    // MARK: - Install state

    /// A module is decoded rather than built: `ModuleDefinition` has a decoder of its own
    /// and no memberwise initializer.
    private func installModule(name: String, jsonUrl: String, version: String) throws -> ModuleDefinition {
        let json = """
        {"sourceName": "\(name)", "version": "\(version)",
         "scriptUrl": "https://example.com/script.js", "type": "anime",
         "jsonUrl": "\(jsonUrl)"}
        """.data(using: .utf8)!
        return try JSONDecoder().decode(ModuleDefinition.self, from: json)
    }

    /// Runs with one module installed, putting the real list back afterwards.
    private func withInstalledModule(_ name: String, jsonUrl: String, version: String,
                                     _ body: () -> Void) throws {
        let saved = ModuleManager.shared.modules
        ModuleManager.shared.modules = [try installModule(name: name, jsonUrl: jsonUrl, version: version)]
        defer { ModuleManager.shared.modules = saved }
        body()
    }

    func testAnInstalledManifestIsRecognized() throws {
        try withInstalledModule(name: "Example", jsonUrl: "https://example.com/module.json", version: "1.0") {
            XCTAssertEqual(store.state(of: entry(id: "a")), .installed)
            XCTAssertEqual(store.state(of: entry(id: "a", version: "1.1")), .updateAvailable)
            XCTAssertEqual(store.state(of: entry(id: "a", version: "0.9")), .installed,
                           "An older catalog entry is not an update")
        }
    }

    func testAnEntryNothingIsInstalledFromIsNotInstalled() throws {
        try withInstalledModule(name: "Other", jsonUrl: "https://example.com/other.json", version: "1.0") {
            XCTAssertEqual(store.state(of: entry(id: "a")), .notInstalled)
        }
    }

    func testAHigherVersionNumbersAreNotAnUpdate() throws {
        // 1.2 against 1.10: ten beats two, and a plain string compare would have it wrong.
        try withInstalledModule(name: "Example", jsonUrl: "https://example.com/module.json", version: "1.10") {
            XCTAssertEqual(store.state(of: entry(id: "a", version: "1.2")), .installed)
            XCTAssertEqual(store.state(of: entry(id: "a", version: "1.11")), .updateAvailable)
        }
    }

    // MARK: - Version compare

    func testVersionOrdering() {
        XCTAssertTrue("1.2".isStoreVersion(atLeast: "1.2"))
        XCTAssertTrue("2.0".isStoreVersion(atLeast: "1.10"))
        XCTAssertTrue("1.2.1".isStoreVersion(atLeast: "1.2"))
        XCTAssertTrue("1.2.0".isStoreVersion(atLeast: "1.2"))
        XCTAssertFalse("1.2".isStoreVersion(atLeast: "1.2.1"))
        XCTAssertFalse("1.2".isStoreVersion(atLeast: "1.10"))
        XCTAssertFalse("0.9".isStoreVersion(atLeast: "1.0"))
    }

    func testEntriesCarryTheFieldsARealCatalogBrings() throws {
        // The fields the skeleton already renders, so later modules light up without
        // store changes.
        let json = """
        {"id": "x", "name": "X", "tagline": "t", "description": "d", "category": "utility",
         "author": "a", "version": "2.0", "iconURL": "https://example.com/icon.png",
         "manifestURL": "https://example.com/x.json", "kind": "utility", "featured": true,
         "screenshots": ["https://example.com/1.png"], "minAppVersion": "1.5"}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(ModuleStoreEntry.self, from: json)
        XCTAssertEqual(entry.kind, .utility)
        XCTAssertEqual(entry.featured, true)
        XCTAssertEqual(entry.screenshots, ["https://example.com/1.png"])
        XCTAssertEqual(entry.minAppVersion, "1.5")
        XCTAssertTrue("2.0".isStoreVersion(atLeast: entry.minAppVersion!))
    }
}
