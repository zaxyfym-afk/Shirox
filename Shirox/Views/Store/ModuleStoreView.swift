import SwiftUI

/// The Store tab: the Module Store's shelves on top, everything already installed below. The
/// shelves are a skeleton — the bundled catalog is an empty placeholder until a real one is
/// published at Settings › Sources — but every part is wired: entries install and update
/// through the existing module manager, and the installed list is the modules themselves.
struct ModuleStoreView: View {
    @ObservedObject private var store = ModuleStoreService.shared
    @ObservedObject private var moduleManager = ModuleManager.shared
    @State private var search = ""
    @State private var category: ModuleStoreCategory?
    @State private var detail: ModuleStoreEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let error = store.errorMessage {
                        errorBanner(error)
                    }

                    if !featured.isEmpty {
                        shelf(title: "store.featured", entries: featured)
                    }

                    if store.showingPlaceholder, store.catalog.entries.isEmpty {
                        placeholderHeader
                    } else {
                        categoryChips
                        shelf(title: selectedCategory?.displayName ?? String(localized: "store.all"),
                              entries: selectedCategory.map { store.entries(in: $0, matching: search) }
                                  ?? store.allEntries(matching: search))
                    }

                    installedSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .softScrollEdges()
            .navigationTitle("store.title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(tvOS)
            .searchable(text: $search, prompt: Text("store.search_modules"))
            #endif
            .morphingRefreshable { await store.load() }
            .adaptiveSheet(item: $detail) { entry in
                ModuleStoreEntryDetail(entry: entry)
            }
        }
    }

    // MARK: - Shelves

    private var featured: [ModuleStoreEntry] { store.featured(matching: search) }

    private var selectedCategory: ModuleStoreCategory? {
        guard let category, store.catalog.categories.contains(category) else { return nil }
        return category
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, label: String(localized: "store.all"))
                ForEach(store.catalog.categories) { category in
                    chip(category, label: category.displayName)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ category: ModuleStoreCategory?, label: String) -> some View {
        let isSelected = selectedCategory?.id == category?.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.category = category
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1))
                )
                .overlay(Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shelf(title: String, entries: [ModuleStoreEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.bold))
            if entries.isEmpty {
                Text("store.nothing_here_yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else {
                ForEach(entries) { entry in
                    Button { detail = entry } label: {
                        entryCard(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Cards

    private func entryCard(_ entry: ModuleStoreEntry) -> some View {
        HStack(spacing: 14) {
            entryIcon(entry)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    stateBadge(entry)
                }
                Text(entry.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let author = entry.author {
                    Text("store.by_author \(author)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            IconView("chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.secondary.opacity(0.07)))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func stateBadge(_ entry: ModuleStoreEntry) -> some View {
        switch store.state(of: entry) {
        case .installed:
            Label("store.installed_badge", icon: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
        case .updateAvailable:
            Text("store.update")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
        case .notInstalled:
            EmptyView()
        }
    }

    @ViewBuilder
    private func entryIcon(_ entry: ModuleStoreEntry) -> some View {
        Group {
            if let url = entry.iconURL, !url.isEmpty {
                CachedAsyncImage(urlString: url)
                    .scaledToFill()
            } else {
                // A monogram stands in until a real catalog brings icons.
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 52, height: 52)
        .background(Color.accentColor.opacity(0.75), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityHidden(true)
    }

    /// The placeholder catalog's own wording: this isn't "nothing found", it's "not yet".
    private var placeholderHeader: some View {
        VStack(spacing: 12) {
            IconView("bag.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("store.the_store_opens_soon")
                .font(.headline)
            Text("store.placeholder_hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            IconView("exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.08)))
    }

    // MARK: - Installed

    /// The modules themselves, from the module manager: what the store's entries stand for.
    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("store.installed_section").font(.title3.weight(.bold))
            if moduleManager.modules.isEmpty {
                VStack(spacing: 8) {
                    IconView("puzzlepiece.extension")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("store.nothing_installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(moduleManager.modules) { module in
                    installedRow(module)
                }
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
            HStack(spacing: 14) {
                CachedAsyncImage(urlString: module.iconUrl ?? "", base64String: module.iconData)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.sourceName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("store.version \(module.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isActive {
                    Label("store.active", icon: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? Color.green.opacity(0.06) : Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                moduleManager.removeModule(module)
            } label: {
                Label("common.remove", icon: "trash")
            }
        }
    }
}

// MARK: - Entry detail

/// One store entry in full: icon, name, author and version, description, the screenshots a
/// real catalog brings, and the install button wired to the module manager. Detented on a
/// Mac-sized sheet so it opens as a half sheet on a phone.
private struct ModuleStoreEntryDetail: View {
    let entry: ModuleStoreEntry

    @ObservedObject private var store = ModuleStoreService.shared
    @ObservedObject private var moduleManager = ModuleManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if entry.screenshots?.isEmpty == false {
                    screenshots
                }
                Text(entry.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let min = entry.minAppVersion,
                   !ModuleStoreService.appVersion.isStoreVersion(atLeast: min) {
                    Label("store.needs_app \(min)", icon: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                installButton
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .softScrollEdges()
    }

    private var header: some View {
        HStack(spacing: 16) {
            Group {
                if let url = entry.iconURL, !url.isEmpty {
                    CachedAsyncImage(urlString: url)
                        .scaledToFill()
                } else {
                    Text(String(entry.name.prefix(1)).uppercased())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.accentColor.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name).font(.title3.weight(.bold))
                if let author = entry.author {
                    Text("store.by_author \(author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("store.version \(entry.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var screenshots: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(entry.screenshots ?? [], id: \.self) { url in
                    CachedAsyncImage(urlString: url)
                        .frame(width: 220, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var installButton: some View {
        VStack(spacing: 10) {
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
                    Text(label(for: store.state(of: entry)))
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(moduleManager.isLoading)

            // Only once something of it is installed: the store removes what it put in.
            if store.state(of: entry) != .notInstalled {
                Button(role: .destructive) {
                    Task {
                        await store.remove(entry)
                        dismiss()
                    }
                } label: {
                    Text("common.remove")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for state: ModuleStoreService.InstallState) -> String {
        switch state {
        case .notInstalled: return String(localized: "store.install")
        case .installed: return String(localized: "store.installed_badge")
        case .updateAvailable: return String(localized: "store.update")
        }
    }
}
