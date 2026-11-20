import SwiftUI

#if !os(tvOS)

/// Netflix-style profile artwork: a grid of anime covers — what's trending, or a search —
/// to use as a profile's picture. Real covers from AniList; nothing ships with the app.
struct AnimeArtworkPickerView: View {
    let onPick: (_ url: String?, _ title: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [AniListMedia] = []
    @State private var search = ""
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if failed && items.isEmpty {
                    ContentUnavailableView(
                        "common.couldnt_load",
                        systemImage: "wifi.exclamationmark",
                        description: Text("profile.artwork_needs_a_connection")
                    )
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "profile.no_artwork_found",
                        systemImage: "photo.on.rectangle",
                        description: Text("profile.try_a_different_search")
                    )
                } else {
                    grid
                }
            }
            .navigationTitle("profile.choose_anime_artwork")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .searchable(text: $search, placement: .navigationBar, prompt: Text("common.search"))
            .onSubmit(of: .search) {
                Task { await load() }
            }
            .task { await load() }
        }
        .macSheetFrame()
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    Button {
                        onPick(item.coverImage.best, item.title.displayTitle)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            CachedAsyncImage(urlString: item.coverImage.best ?? "")
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(item.title.displayTitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func load() async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        failed = false
        do {
            items = try await AniListService.shared.profileArtwork(search: query.isEmpty ? nil : query)
        } catch {
            failed = true
        }
        isLoading = false
    }
}

#endif
