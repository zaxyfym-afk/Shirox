import Foundation
import SwiftUI

/// The Module Store: a storefront in front of the module system that already exists.
///
/// The shelves draw from the two community catalogs the user supplied — the Cufiy library
/// and the xdfkenny index — fetched fresh on every load and merged into one set of entries,
/// plus a user-set catalog URL kept from before. Anime only for now: entries whose type or
/// category doesn't mention anime (K-drama, live action, novels, live TV) are left out, per
/// the store's plan. Installing, updating and removing are the existing `ModuleManager`'s,
/// untouched — an entry's manifest link is all the manager needs, whatever ecosystem it
/// belongs to.
@MainActor
final class ModuleStoreService: ObservableObject {
    static let shared = ModuleStoreService()

    static let catalogURLKey = "moduleStoreCatalogURL"

    /// The two catalog links, as given. Cufiy publishes one flat JSON document of every
    /// module; xdfkenny publishes an index whose entries point at per-module manifests.
    static let cufiyCatalogURL = URL(string: "https://library.cufiy.net/api/modules.json")!
    static let xdfkennyCatalogURL = URL(string: "https://sora-modules.xdfke.me/modules.json")!

    /// Where an extra catalog is published, set by hand; empty means just the two built-ins
    /// and the bundled placeholder.
    @AppStorage(ModuleStoreService.catalogURLKey) var catalogURL = ""

    /// How one catalog answered its fetch, so the store can say which shelves are fresh
    /// and which source is down or behind Cloudflare.
    struct SourceStatus: Identifiable, Equatable {
        let name: String
        let health: SourceHealth
        var id: String { name }
    }

    /// Where a source stands after its load.
    enum SourceHealth: Equatable {
        case loaded(count: Int)
        case failed(reason: String)
    }

    @Published private(set) var catalog: ModuleStoreCatalog = ModuleStoreService.builtInShelves
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var sourceStatuses: [SourceStatus] = []

    /// Whether nothing real has answered yet — the empty state words itself differently
    /// for the bundled placeholder than for a catalog with entries.
    @Published private(set) var showingPlaceholder = true

    /// Install state is read on demand, so the view observing the module manager stays the
    /// one thing that refreshes it.
    private let moduleManager = ModuleManager.shared

    private init() {
        Task { await load() }
    }

    // MARK: - Catalog

    /// The store's shelves. Manga stays out for now — the anime and multi-anime entries of
    /// both sources land on the video shelf — so the chips are the three built-ins until a
    /// catalog brings its own.
    static let builtInShelves = ModuleStoreCatalog(
        categories: [
            ModuleStoreCategory(id: "video", name: "Video", kind: .video),
            ModuleStoreCategory(id: "manga", name: "Manga", kind: .manga),
            ModuleStoreCategory(id: "utility", name: "Utility", kind: .utility)
        ],
        entries: []
    )

    /// Every source, fetched, mapped and merged. A source that fails says so in
    /// `sourceStatuses` without taking the others down; when nothing answers, the bundled
    /// placeholder shows and the error banner explains.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var entries: [ModuleStoreEntry] = []
        var statuses: [SourceStatus] = []

        await withTaskGroup(of: (SourceStatus, [ModuleStoreEntry]).self) { group in
            group.addTask { await Self.fetchCufiy() }
            group.addTask { await Self.fetchXdfkenny() }
            if let custom = Self.customCatalogURL(from: catalogURL) {
                group.addTask { await Self.fetchCustom(custom) }
            }
            for await (status, fetched) in group {
                statuses.append(status)
                entries.append(contentsOf: fetched)
            }
        }

        sourceStatuses = statuses.sorted { $0.name < $1.name }

        let answered = statuses.contains {
            if case .loaded(let count) = $0.health { return count > 0 }
            return false
        }
        if answered {
            catalog = ModuleStoreCatalog(categories: Self.builtInShelves.categories,
                                         entries: Self.merged(entries))
            showingPlaceholder = false
            errorMessage = nil
        } else {
            catalog = Self.bundledCatalog() ?? Self.builtInShelves
            showingPlaceholder = true
            errorMessage = statuses.compactMap { status in
                if case .failed(let reason) = status.health { return "\(status.name): \(reason)" }
                return nil
            }.joined(separator: "\n")
        }
    }

    /// One entry per manifest: the two sources overlap, and the same module listed twice is
    /// noise, not choice.
    static func merged(_ entries: [ModuleStoreEntry]) -> [ModuleStoreEntry] {
        var seen = Set<String>()
        return entries.filter { seen.insert(normalizedManifest($0.manifestURL)).inserted }
    }

    /// The two spellings of one GitHub raw URL — with and without `refs/heads` — are one
    /// manifest, so the key folds them together.
    static func normalizedManifest(_ link: String) -> String {
        guard var components = URLComponents(string: link) else { return link }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.path = components.path
            .replacingOccurrences(of: "/refs/heads/", with: "/")
        if components.path.hasSuffix("/") { components.path.removeLast() }
        return components.string ?? link
    }

    private static func customCatalogURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    /// Cufiy: one flat JSON array. Cloudflare sits in front of it, so a plain client can be
    /// challenged — the fetch goes out with a browser user agent, and a challenge lands in
    /// the source's status, not in a crash.
    private static func fetchCufiy() async -> (SourceStatus, [ModuleStoreEntry]) {
        await fetch(cufiyCatalogURL, name: "Cufiy library") { data in
            let modules = try JSONDecoder().decode([CufiyModule].self, from: data)
            return modules.compactMap(Self.entry(from:))
        }
    }

    /// xdfkenny: an index of per-module manifests. The index itself is the store's entries;
    /// hydration happens through the manifest link at install time, as it always has.
    private static func fetchXdfkenny() async -> (SourceStatus, [ModuleStoreEntry]) {
        await fetch(xdfkennyCatalogURL, name: "xdfkenny modules") { data in
            let index = try JSONDecoder().decode(XdfkennyIndex.self, from: data)
            return (index.modules ?? []).compactMap(Self.entry(from:))
        }
    }

    /// The user's own catalog, in the store's native shape.
    private static func fetchCustom(_ url: URL) async -> (SourceStatus, [ModuleStoreEntry]) {
        await fetch(url, name: url.host ?? "Custom catalog") { data in
            let catalog = try JSONDecoder().decode(ModuleStoreCatalog.self, from: data)
            return catalog.entries
        }
    }

    private static func fetch(_ url: URL, name: String,
                              decode: (Data) throws -> [ModuleStoreEntry]) async -> (SourceStatus, [ModuleStoreEntry]) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (SourceStatus(name: name, health: .failed(reason: "no response")), [])
            }
            guard (200..<300).contains(http.statusCode) else {
                let reason = http.statusCode == 403
                    ? "blocked by Cloudflare, try again later"
                    : "HTTP \(http.statusCode)"
                return (SourceStatus(name: name, health: .failed(reason: reason)), [])
            }
            let entries = try decode(data)
            return (SourceStatus(name: name, health: .loaded(count: entries.count)), entries)
        } catch {
            return (SourceStatus(name: name, health: .failed(reason: error.localizedDescription)), [])
        }
    }

    // MARK: - Cufiy mapping

    /// Cufiy's flat document. Fields are optional on purpose: the catalog is edited by hand
    /// upstream, and one odd entry must not cost the shelf the rest.
    private struct CufiyModule: Decodable {
        let id: String?
        let sourceName: String?
        let iconUrl: String?
        let version: String?
        let language: String?
        let streamType: String?
        let quality: String?
        let manifestUrl: String?
        let type: String?
        let note: String?
        let featured: Int?
        let author: CufiyAuthor?
    }

    private struct CufiyAuthor: Decodable {
        let name: String?
    }

    /// Anime only: the type line names the audiences a module serves, and a module not
    /// serving anime at all (K-drama, live action, novels) has no business on the shelf.
    private static func isAnime(_ type: String?) -> Bool {
        (type ?? "").lowercased().contains("anime")
    }

    private static func entry(from module: CufiyModule) -> ModuleStoreEntry? {
        guard isAnime(module.type),
              let name = module.sourceName, !name.isEmpty,
              let manifest = module.manifestUrl, !manifest.isEmpty else { return nil }

        let facts = [module.language, module.streamType, module.quality]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let tagline = facts.isEmpty ? "Community module" : facts.joined(separator: " · ")

        let description: String
        if let note = module.note, !note.isEmpty {
            description = note
        } else {
            description = "\(tagline). Installed through its manifest, managed with the rest of your modules."
        }

        return ModuleStoreEntry(
            id: "cufiy-\(module.id ?? name)",
            name: name,
            tagline: tagline,
            description: description,
            category: "video",
            author: module.author?.name,
            version: module.version ?? "",
            iconURL: module.iconUrl,
            manifestURL: manifest,
            kind: .video,
            featured: module.featured == 1 ? true : nil,
            screenshots: nil,
            minAppVersion: nil
        )
    }

    // MARK: - xdfkenny mapping

    /// The index document: a repo link and the module list the store shelves.
    private struct XdfkennyIndex: Decodable {
        let repo: String?
        let modules: [XdfkennyModule]?
    }

    /// One index entry; hydration happens through the manifest at install time.
    private struct XdfkennyModule: Decodable {
        let id: String?
        let name: String?
        let iconUrl: String?
        let category: String?
        let manifestUrl: String?
        let sampleQuery: String?
        let updated: String?
        let note: String?
    }

    private static func entry(from module: XdfkennyModule) -> ModuleStoreEntry? {
        guard isAnime(module.category),
              let name = module.name, !name.isEmpty,
              let manifest = module.manifestUrl, !manifest.isEmpty else { return nil }

        // Manga-only shelves stay out for now; a mixed category mentioning anime stays in.
        var description = "Sora module, installed through its manifest and managed with the rest of your modules."
        if let note = module.note, !note.isEmpty {
            let firstLine = note.split(separator: "\n").first.map(String.init) ?? note
            description = firstLine.count > 240 ? String(firstLine.prefix(240)) + "…" : firstLine
        }
        if let sample = module.sampleQuery, !sample.isEmpty {
            description += " Try searching “\(sample)”."
        }

        return ModuleStoreEntry(
            id: "xdf-\(module.id ?? name)",
            name: name,
            tagline: (module.category ?? "anime").replacingOccurrences(of: "/", with: " · "),
            description: description,
            category: "video",
            author: nil,
            version: module.updated ?? "",
            iconURL: module.iconUrl,
            manifestURL: manifest,
            kind: .video,
            featured: nil,
            screenshots: nil,
            minAppVersion: nil
        )
    }

    /// The bundled placeholder, or nil when the bundle doesn't carry it (a packaging change,
    /// say) — the empty catalog stands in.
    static func bundledCatalog() -> ModuleStoreCatalog? {
        guard let url = Bundle.main.url(forResource: "default-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ModuleStoreCatalog.self, from: data)
    }

    /// Testing and previews: the catalog as it would be if a real one had been fetched.
    func adopt(_ catalog: ModuleStoreCatalog) {
        self.catalog = catalog
        showingPlaceholder = false
    }

    // MARK: - Browsing

    /// One shelf, its entries filtered to a search when there is one.
    func entries(in category: ModuleStoreCategory, matching search: String = "") -> [ModuleStoreEntry] {
        let shelf = catalog.entries.filter { $0.category == category.id }
        return filtered(shelf, matching: search)
    }

    /// The curated header: featured entries, whatever shelf they sit on.
    func featured(matching search: String = "") -> [ModuleStoreEntry] {
        filtered(catalog.entries.filter { $0.featured == true }, matching: search)
    }

    /// Every entry answering a search, across shelves.
    func allEntries(matching search: String) -> [ModuleStoreEntry] {
        filtered(catalog.entries, matching: search)
    }

    private func filtered(_ entries: [ModuleStoreEntry], matching search: String) -> [ModuleStoreEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.tagline.localizedCaseInsensitiveContains(query)
                || ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Install state

    enum InstallState: Equatable {
        case notInstalled
        case installed
        case updateAvailable
    }

    /// How the installed modules stand against an entry: installed from its manifest, and
    /// current or behind its version.
    func state(of entry: ModuleStoreEntry) -> InstallState {
        guard let installed = installedModule(for: entry) else { return .notInstalled }
        guard !installed.version.isEmpty else { return .installed }
        return installed.version == entry.version || installed.version.isStoreVersion(atLeast: entry.version)
            ? .installed
            : .updateAvailable
    }

    /// The installed module an entry stands for: one installed from its manifest link, or —
    /// a manifest since moved — one with its name and script.
    func installedModule(for entry: ModuleStoreEntry) -> ModuleDefinition? {
        guard let manifest = URL(string: entry.manifestURL) else { return nil }
        let normalized = ExtensionRepoLoader.normalized(manifest).absoluteString
        return moduleManager.modules.first {
            $0.jsonUrl == normalized || $0.jsonUrl == entry.manifestURL
                || ($0.sourceName == entry.name && $0.scriptUrl.contains(entry.id))
        }
    }

    // MARK: - Install / update / remove

    /// Install (or update — `addModule` replaces in place): the existing manager does it,
    /// handling every ecosystem the manifest might belong to.
    func install(_ entry: ModuleStoreEntry) async {
        guard let url = URL(string: entry.manifestURL) else {
            errorMessage = String(localized: "store.no_manifest_for \(entry.name)")
            return
        }
        await moduleManager.addModule(from: url)
    }

    /// Remove the module an entry stands for; a no-op for one that isn't installed.
    func remove(_ entry: ModuleStoreEntry) async {
        guard let installed = installedModule(for: entry) else { return }
        moduleManager.removeModule(installed)
    }

    // MARK: - The user's app version, for entries that need a newer one

    /// The running app's marketing version, as the store compares it.
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
