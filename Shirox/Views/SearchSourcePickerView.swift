import SwiftUI

/// Search's source picker, rebuilt as a selector rather than a settings list: the chosen
/// source announced up top, then the sources themselves as tiles — the built-in metadata
/// sources first, then the installed modules that actually search anime. Manga, local-files
/// and Jellyfin modules are not anime search sources and don't appear; module management
/// lives in Settings › Modules.
struct SearchSourcePickerView: View {
    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var providerManager = ProviderManager.shared
    @ObservedObject private var discovery = DiscoverySource.shared
    @ObservedObject private var simklAuth = SimklAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Modules that search anime: a video module with its own search endpoint. Manga,
    /// local files and Jellyfin are libraries, not sources to search anime with.
    private var animeSearchModules: [ModuleDefinition] {
        moduleManager.modules.filter {
            !$0.isLocalPlayback && !$0.isJellyfin && !$0.isManga && $0.searchBaseUrl != nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                currentSelection
                builtInTiles
                if !animeSearchModules.isEmpty {
                    moduleTiles
                }
                note
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .softScrollEdges()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("search.source_title")
        .navigationBarTitleDisplayMode(.inline)
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 420)
        #endif
    }

    // MARK: - Current selection

    /// The one line that says what search answers to right now, with the source's own icon.
    private var currentSelection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 46, height: 46)
                selectionIcon
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("search.current_source")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectionName)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var selectionIcon: some View {
        if moduleManager.activeModule != nil {
            if let module = moduleManager.activeModule {
                ModuleIconView(module: module, side: 30, cornerRadius: 8)
            }
        } else if discovery.usesSimkl {
            SourceTileImage(url: ProviderType.simkl.iconURL, onWhite: true)
        } else if let first = providerManager.orderedProviders.first {
            SourceTileImage(url: first.providerType.iconURL, onWhite: false)
        }
    }

    private var selectionName: String {
        if let module = moduleManager.activeModule { return module.sourceName }
        if discovery.usesSimkl { return ProviderType.simkl.displayName }
        if let first = providerManager.orderedProviders.first { return first.providerType.displayName }
        return "—"
    }

    // MARK: - Tiles

    /// Sources as tiles in a grid: icon, name, and a checkmark badge on the chosen one.
    private var builtInTiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("search.builtin_sources")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                tile(.anilist)
                tile(.mal)
                if simklAuth.isLoggedIn {
                    tile(.simkl)
                }
            }
        }
    }

    private var moduleTiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("search.source_modules")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(animeSearchModules) { module in
                    moduleTile(module)
                }
            }
        }
    }

    private func tile(_ type: ProviderType) -> some View {
        let isChosen = type == .simkl
            ? discovery.usesSimkl
            : !discovery.usesSimkl && moduleManager.activeModule == nil
                && providerManager.orderedProviders.first?.providerType == type
        return Button {
            if moduleManager.activeModule != nil {
                moduleManager.deselectModule()
            }
            if type == .simkl {
                discovery.chooseSimkl()
            } else {
                discovery.chooseProvider(type)
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            dismiss()
        } label: {
            sourceTileContent(
                icon: AnyView(SourceTileImage(url: type.iconURL, onWhite: type == .simkl)),
                name: type.displayName,
                isChosen: isChosen
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func moduleTile(_ module: ModuleDefinition) -> some View {
        let isChosen = moduleManager.activeModule?.id == module.id
        return Button {
            if !isChosen {
                moduleManager.selectModule(module)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
            dismiss()
        } label: {
            sourceTileContent(
                icon: AnyView(ModuleIconView(module: module, side: 40, cornerRadius: 10)),
                name: module.sourceName,
                isChosen: isChosen
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// One tile: the icon on its quiet square, the name under it, and on the chosen tile a
    /// filled checkmark riding the corner. Selected tiles lift slightly.
    private func sourceTileContent(icon: AnyView, name: String, isChosen: Bool) -> some View {
        VStack(spacing: 8) {
            icon
                .frame(width: 40, height: 40)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            Text(name)
                .font(.caption.weight(isChosen ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isChosen ? Color.accentColor : Color.primary.opacity(0.06),
                              lineWidth: isChosen ? 1.5 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isChosen {
                IconView("checkmark.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(isChosen ? 1.02 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isChosen)
    }

    private var note: some View {
        Text("search.module_note")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}

/// A source's icon at tile size, on the white square the dark logos need.
struct SourceTileImage: View {
    let url: String
    var onWhite = false

    var body: some View {
        CachedAsyncImage(urlString: url)
            .frame(width: 40, height: 40)
            .background(onWhite ? Color.white : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
