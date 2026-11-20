import Foundation
import SwiftUI

/// The Module Store: a storefront in front of the module system that already exists. It owns
/// the catalog (a JSON document, from a configurable URL with a bundled placeholder to start)
/// and the mapping between a catalog entry and the modules installed; installing, updating
/// and removing are the existing `ModuleManager`'s, untouched.
@MainActor
final class ModuleStoreService: ObservableObject {
    static let shared = ModuleStoreService()

    static let catalogURLKey = "moduleStoreCatalogURL"

    /// Where a real catalog is published; empty means the bundled placeholder.
    @AppStorage(ModuleStoreService.catalogURLKey) var catalogURL = ""

    @Published private(set) var catalog: ModuleStoreCatalog = .empty
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Whether the placeholder catalog is what's showing — the empty state words itself
    /// differently for it.
    @Published private(set) var showingPlaceholder = true

    /// Install state is read on demand, so the view observing the module manager stays the
    /// one thing that refreshes it.
    private let moduleManager = ModuleManager.shared

    private init() {
        Task { await load() }
    }

    // MARK: - Catalog

    /// The catalog, from its URL when one is set, else the bundled placeholder. A failed
    /// fetch keeps whatever was showing and says so; an empty catalog is a state, not an
    /// error.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: catalogURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.hasPrefix("http") == true else {
            catalog = Self.bundledCatalog() ?? .empty
            showingPlaceholder = true
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            catalog = try JSONDecoder().decode(ModuleStoreCatalog.self, from: data)
            showingPlaceholder = false
        } catch {
            errorMessage = error.localizedDescription
            if showingPlaceholder, catalog.entries.isEmpty {
                catalog = Self.bundledCatalog() ?? .empty
            }
        }
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
