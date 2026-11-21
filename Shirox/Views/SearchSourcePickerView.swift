import SwiftUI

/// Search's source picker: the anime sources this app actually searches, one tap to switch.
/// AniList and MyAnimeList are the built-in metadata sources; Simkl joins them while signed
/// in; the installed modules that can search sit under them as "Modules". Nothing else from
/// module management lives here — that's Settings › Modules.
struct SearchSourcePickerView: View {
    @EnvironmentObject private var moduleManager: ModuleManager
    @ObservedObject private var providerManager = ProviderManager.shared
    @ObservedObject private var discovery = DiscoverySource.shared
    @ObservedObject private var simklAuth = SimklAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Modules that can search anime: a video module's search drives this page when active.
    /// Local files and Jellyfin are libraries, not sources to search.
    private var searchModules: [ModuleDefinition] {
        moduleManager.modules.filter { !$0.isLocalPlayback && !$0.isJellyfin }
    }

    var body: some View {
        NavigationStack {
            List {
                builtInSection
                if !searchModules.isEmpty {
                    moduleSection
                }
            }
            .softScrollEdges()
            .navigationTitle("search.source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    // MARK: - Built-in sources

    private var builtInSection: some View {
        Section {
            sourceRow(.anilist)
            sourceRow(.mal)
            if simklAuth.isLoggedIn {
                sourceRow(.simkl)
            }
        }
    }

    private func sourceRow(_ type: ProviderType) -> some View {
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
            HStack(spacing: 12) {
                SourceIcon(url: type.iconURL, onWhite: type == .simkl)
                Text(type.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if isChosen {
                    IconView("checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    // MARK: - Modules

    private var moduleSection: some View {
        Section {
            ForEach(searchModules) { module in
                moduleRow(module)
            }
        } header: {
            Text("search.source_modules")
        }
    }

    private func moduleRow(_ module: ModuleDefinition) -> some View {
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
            HStack(spacing: 12) {
                ModuleIconView(module: module, side: 28, cornerRadius: 7)
                Text(module.sourceName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if isChosen {
                    IconView("checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A source's icon at picker size, on the white tile the dark logos need.
private struct SourceIcon: View {
    let url: String
    var onWhite = false

    var body: some View {
        CachedAsyncImage(urlString: url)
            .frame(width: 28, height: 28)
            .background(onWhite ? Color.white : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
