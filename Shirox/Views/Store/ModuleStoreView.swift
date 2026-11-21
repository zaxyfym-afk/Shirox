import SwiftUI

/// The Module Store: the community catalogs' modules, searchable and shelved, over what's
/// already installed. Every entry installs through the existing module manager; the detail
/// page offers Install, Test and Copy Link — nothing decorative.
struct ModuleStoreView: View {
    @ObservedObject private var store = ModuleStoreService.shared
    @ObservedObject private var moduleManager = ModuleManager.shared
    @State private var search = ""
    @State private var category: ModuleStoreCategory?
    @State private var detail: ModuleStoreEntry?

    var body: some View {
        List {
            if store.state == .offline && store.catalog.entries.isEmpty {
                Section {
                    offlineState
                }
            } else {
                if store.state == .cached {
                    Section {
                        Label("store.showing_cached", icon: "clock.arrow.circlepath")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                sourceNotes
                categorySection
                entriesSection
            }
            installedSection
        }
        .softScrollEdges()
        .navigationTitle("store.title")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        #if !os(tvOS)
        .searchable(text: $search, prompt: Text("store.search_modules"))
        #endif
        .morphingRefreshable { await store.load() }
        .adaptiveSheet(item: $detail) { entry in
            ModuleStoreEntryDetail(entry: entry)
        }
    }

    /// No catalog answered and nothing is saved: an honest outage state with a retry, not a
    /// promise that shelves are coming.
    private var offlineState: some View {
        VStack(spacing: 10) {
            IconView("wifi.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("store.offline_title")
                .font(.headline)
            Text("store.offline_hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await store.load() }
            } label: {
                Label("common.retry", icon: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    // MARK: - Source health

    /// The catalogs' health, one quiet line per source that didn't answer — the shelves that
    /// did answer stay up, and the pull to refresh tries the failed ones again.
    @ViewBuilder
    private var sourceNotes: some View {
        let failed = store.sourceStatuses.filter {
            if case .failed = $0.health { return true }
            return false
        }
        if !failed.isEmpty {
            Section {
                ForEach(failed) { status in
                    HStack(spacing: 8) {
                        IconView("wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        Text("store.source_unavailable \(status.name)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Categories

    private var selectedCategory: ModuleStoreCategory? {
        guard let category, store.catalog.categories.contains(category) else { return nil }
        return category
    }

    /// The shelves as a single row of plain chips. Selected is solid; the rest sit quiet.
    private var categorySection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(nil, label: String(localized: "store.all"))
                    ForEach(store.catalog.categories) { category in
                        chip(category, label: category.displayName)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func chip(_ category: ModuleStoreCategory?, label: String) -> some View {
        let isSelected = selectedCategory?.id == category?.id
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                self.category = category
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
                )
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entries

    @ViewBuilder
    private var entriesSection: some View {
        let entries = selectedCategory.map { store.entries(in: $0, matching: search) }
            ?? store.allEntries(matching: search)
        Section {
            if entries.isEmpty {
                Text("store.nothing_here_yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 22)
            } else {
                ForEach(entries) { entry in
                    Button { detail = entry } label: {
                        entryRow(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// One module: its icon, its name, one quiet line of what it is. No cards, no decoration.
    private func entryRow(_ entry: ModuleStoreEntry) -> some View {
        HStack(spacing: 12) {
            StoreEntryIconView(entry: entry, side: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let line = entryLine(entry) {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            stateBadge(entry)
            IconView("chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    /// The row's second line: the author when there is one, else the tagline, else nothing.
    private func entryLine(_ entry: ModuleStoreEntry) -> String? {
        if let author = entry.author, !author.isEmpty { return author }
        let tagline = entry.tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        return tagline.isEmpty || tagline == "Community module" ? nil : tagline
    }

    @ViewBuilder
    private func stateBadge(_ entry: ModuleStoreEntry) -> some View {
        switch store.state(of: entry) {
        case .installed:
            Text("store.installed_badge")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.07), in: Capsule())
        case .updateAvailable:
            Text("store.update")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.07), in: Capsule())
                .foregroundStyle(.primary)
        case .notInstalled:
            EmptyView()
        }
    }

    // MARK: - Installed

    /// The modules themselves, from the module manager: what the store's entries stand for.
    @ViewBuilder
    private var installedSection: some View {
        if !moduleManager.modules.isEmpty {
            Section {
                ForEach(moduleManager.modules) { module in
                    installedRow(module)
                }
            } header: {
                Text("store.installed_section")
            }
        }
    }

    private func installedRow(_ module: ModuleDefinition) -> some View {
        let isActive = moduleManager.activeModule?.id == module.id
        return Button {
            if !isActive {
                moduleManager.selectModule(module)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        } label: {
            HStack(spacing: 12) {
                ModuleIconView(module: module, side: 38, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.sourceName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !module.version.isEmpty {
                        Text("store.version \(module.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isActive {
                    IconView("checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry icon

/// A store entry's icon: the catalog's image when there is one (a link or an inline `data:`
/// URI), else the first letter on a quiet tile — never a broken-image box.
struct StoreEntryIconView: View {
    let entry: ModuleStoreEntry
    var side: CGFloat = 42
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let base64 = Self.base64Payload(fromDataURI: entry.iconURL) {
                CachedAsyncImage(urlString: "", base64String: base64, contentMode: .fit)
                    .padding(3)
            } else if let url = entry.iconURL, !url.isEmpty {
                CachedAsyncImage(urlString: url, contentMode: .fit)
                    .padding(3)
            } else {
                monogram
            }
        }
        .frame(width: side, height: side)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private static func base64Payload(fromDataURI uri: String?) -> String? {
        guard let uri, uri.hasPrefix("data:") else { return nil }
        guard let comma = uri.firstIndex(of: ",") else { return nil }
        return String(uri[uri.index(after: comma)...])
    }

    private var monogram: some View {
        Text(String(entry.name.prefix(1)).uppercased())
            .font(.system(size: side * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Entry detail

/// One store entry in full: what it is, and the three things to do — Install, Test, Copy
/// Link. The Test runs the module the way playing runs it; on an entry that isn't installed
/// yet it says so rather than pretending.
private struct ModuleStoreEntryDetail: View {
    let entry: ModuleStoreEntry

    @ObservedObject private var store = ModuleStoreService.shared
    @ObservedObject private var moduleManager = ModuleManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var testOutcome: ModuleDetailOutcome?
    @State private var confirmingRemoval = false
    /// True while the manifest check runs, so the button can't be tapped twice and the
    /// label can say what's happening.
    @State private var isCheckingManifest = false

    private var installState: ModuleStoreService.InstallState { store.state(of: entry) }
    private var installed: ModuleDefinition? { store.installedModule(for: entry) }
    private var isBusy: Bool { testOutcome == .running || isCheckingManifest }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    actions
                    if let testOutcome {
                        ModuleTestResultView(outcome: testOutcome)
                    }
                    facts
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .softScrollEdges()
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .confirmationDialog("modules.remove_module_title", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("common.remove", role: .destructive) {
                    Task {
                        await store.remove(entry)
                        dismiss()
                    }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("modules.remove_module_message \(entry.name)")
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private var header: some View {
        HStack(spacing: 14) {
            StoreEntryIconView(entry: entry, side: 64, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if let author = entry.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if installState == .installed {
                    Label("store.installed_badge", icon: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            installButton

            Button {
                runTest()
            } label: {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    }
                    Text(testButtonTitle)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(isBusy ? 0.04 : 0.08))
                )
                .foregroundStyle(isBusy ? Color.secondary : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityHint(isInstalled ? Text("") : Text("store.manifest_check_note"))

            if !isInstalled {
                Text("store.manifest_check_note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Clipboard.copy(entry.manifestURL)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                ToastManager.shared.show(message: String(localized: "store.link_copied"), type: .success, duration: 1.6)
            } label: {
                Label("modules.copy_link", icon: "doc.on.doc")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)

            if installState != .notInstalled {
                Button(role: .destructive) {
                    confirmingRemoval = true
                } label: {
                    Label("common.remove", icon: "trash")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var installButton: some View {
        Button {
            Task {
                await store.install(entry)
                // A repo manifest opens the sheet listing its providers rather than installing
                // straight away, so the detail sheet stays up unless it's done.
                if case .installed = store.state(of: entry) { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if moduleManager.isLoading {
                    ProgressView().controlSize(.small)
                }
                Text(label(for: installState))
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(moduleManager.isLoading)
    }

    /// The check the button runs: an installed module goes through the real pipeline —
    /// script load, search, episodes, streams — and a not-installed entry gets a manifest
    /// check, which reports what it found and never claims playback. Each guarded against
    /// double taps by the busy flags.
    private func runTest() {
        guard !isBusy else { return }
        if let installed {
            testOutcome = .running
            Task {
                let result = await moduleManager.check(installed)
                testOutcome = ModuleDetailOutcome(result)
            }
        } else {
            isCheckingManifest = true
            testOutcome = nil
            Task {
                let check = await ModuleStoreService.checkManifest(of: entry)
                isCheckingManifest = false
                switch check {
                case .ok(_, _, let detail): testOutcome = .manifestOk(detail: detail)
                case .failed(let reason): testOutcome = .manifestFailed(reason: reason)
                }
            }
        }
    }

    private var isInstalled: Bool { installed != nil }

    private var testButtonTitle: String {
        if testOutcome == .running || isCheckingManifest { return String(localized: "modules.testing") }
        return isInstalled ? String(localized: "modules.test") : String(localized: "store.check_manifest")
    }

    // MARK: - Facts

    /// Version, compatibility and source — one quiet line each, nothing padded.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.version.isEmpty {
                fact("modules.version", "v\(entry.version)")
            }
            if let min = entry.minAppVersion {
                let ok = ModuleStoreService.appVersion.isStoreVersion(atLeast: min)
                fact("store.compatibility",
                     ok ? String(localized: "store.compatible") : String(localized: "store.needs_app \(min)"))
            }
            if let host = URL(string: entry.manifestURL)?.host {
                fact("modules.source", host)
            }
        }
    }

    private func fact(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private func label(for state: ModuleStoreService.InstallState) -> String {
        switch state {
        case .notInstalled: return String(localized: "store.install")
        case .installed: return String(localized: "store.reinstall")
        case .updateAvailable: return String(localized: "store.update")
        }
    }
}
