import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Cross-platform clipboard writes. tvOS has no user-facing pasteboard, so copy
/// affordances are compiled out there rather than silently doing nothing.
enum Clipboard {
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    /// The text on the clipboard, if any. iOS may ask the user before handing it over.
    static var string: String? {
        #if os(iOS)
        UIPasteboard.general.string
        #elseif os(macOS)
        NSPasteboard.general.string(forType: .string)
        #else
        nil
        #endif
    }
}

/// The full title, then Copy Title: the top of a card's long-press menu.
///
/// Cards shorten long titles (see `CardTitle`), so holding one is how to read the whole name
/// without searching for it. Put it first in a card's own menu, or use `fullTitleContextMenu`
/// on a card that has none. Nothing when the title is blank; no copy on tvOS (no clipboard).
struct FullTitleMenuItems: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section {
                Text(title)
                #if !os(tvOS)
                Button {
                    Clipboard.copy(title)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    ToastManager.shared.show(message: String(localized: "shared.title_copied"), type: .success, duration: 1.6)
                    #endif
                } label: {
                    Label("shared.copy_title", icon: "doc.on.doc")
                }
                #endif
            }
        }
    }
}

extension View {
    /// Long-press (right-click on macOS) a card to read its full title and copy it.
    @ViewBuilder
    func fullTitleContextMenu(_ title: String) -> some View {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self
        } else {
            self.contextMenu { FullTitleMenuItems(title) }
        }
    }

    /// Long-press (right-click on macOS) to copy a media title. On iOS it confirms
    /// with the app's standard toast so the copy isn't a silent no-feedback action.
    ///
    /// Attaches nothing when the title is blank — an empty menu item that copies
    /// `""` is worse than no menu — and nothing on tvOS, which has no clipboard UI.
    @ViewBuilder
    func copyTitleContextMenu(_ title: String) -> some View {
        #if os(tvOS)
        self
        #else
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self
        } else {
            self.contextMenu {
                Button {
                    Clipboard.copy(title)
                    #if os(iOS)
                    // `ToastManager` lives in an iOS-only file; macOS copies silently,
                    // which is the platform convention there anyway.
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    ToastManager.shared.show(message: String(localized: "shared.title_copied"), type: .success, duration: 1.6)
                    #endif
                } label: {
                    Label("shared.copy_title", icon: "doc.on.doc")
                }
            }
        }
        #endif
    }

    /// Long-press (right-click on macOS) to copy a failure message.
    ///
    /// Download errors carry the detail that makes them actionable — which segment 404'd, which
    /// host refused — and that is exactly the part a two-line row truncates away.
    @ViewBuilder
    func copyErrorContextMenu(_ message: String?) -> some View {
        #if os(tvOS)
        self
        #else
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contextMenu {
                Button {
                    Clipboard.copy(message)
                    #if os(iOS)
                    ToastManager.shared.show(message: String(localized: "shared.error_copied"), type: .success, duration: 1.6)
                    #endif
                } label: {
                    Label("shared.copy_error", icon: "doc.on.doc")
                }
            }
        } else {
            self
        }
        #endif
    }

    /// Long-press (right-click on macOS) to copy a synopsis.
    ///
    /// Asked for so a description can be pasted somewhere else to check it matches the season
    /// you think you're starting — some modules label seasons wrongly but describe them
    /// correctly, and the synopsis is the thing worth comparing.
    ///
    /// Attaches nothing when there's no description, and nothing on tvOS, which has no
    /// clipboard UI.
    @ViewBuilder
    func copyDescriptionContextMenu(_ description: String?) -> some View {
        #if os(tvOS)
        self
        #else
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contextMenu {
                Button {
                    Clipboard.copy(description)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    ToastManager.shared.show(message: String(localized: "shared.description_copied"), type: .success, duration: 1.6)
                } label: {
                    Label("shared.copy_description", icon: "doc.on.doc")
                }
            }
        } else {
            self
        }
        #endif
    }
}

// MARK: - Anime long-press actions

/// What a title can be linked out to. AniList and MyAnimeList are different databases with
/// different ids — an AniList id is never a MAL id — so each link is built from its own
/// identifier, and a title without one gets no link rather than a broken one.
enum AnimeExternalLink {
    case anilist(id: Int, isManga: Bool)
    case mal(id: Int, isManga: Bool)

    var url: URL? {
        switch self {
        case .anilist(let id, let isManga):
            return URL(string: "https://anilist.co/\(isManga ? "manga" : "anime")/\(id)")
        case .mal(let id, let isManga):
            return URL(string: "https://myanimelist.net/\(isManga ? "manga" : "anime")/\(id)")
        }
    }

    /// AniList's link, from the media's own provider id: an AniList title's `id` is its
    /// AniList id; anything else has none to give here.
    static func anilist(for media: Media) -> AnimeExternalLink? {
        guard media.provider == .anilist else { return nil }
        return .anilist(id: media.id, isManga: media.isManga)
    }

    /// MyAnimeList's link, from the media's MAL id — the field AniList titles carry, or the
    /// id itself on a MAL-provider title.
    static func mal(for media: Media) -> AnimeExternalLink? {
        let malId: Int?
        if media.provider == .mal {
            malId = media.id
        } else {
            malId = media.idMal
        }
        guard let malId else { return nil }
        return .mal(id: malId, isManga: media.isManga)
    }
}

/// The long-press menu for an anime or manga card: open the details, the two trackers'
/// pages, the library statuses the signed-in service takes, favourites, sharing, and the
/// copies. Every action is real: a link builds from its own id or doesn't appear, and the
/// tracking rows talk to the provider the title came from.
///
/// `onOpenDetails` is for rows a tap doesn't already open — a library row's menu, a
/// schedule entry's. Cards that already push the details on tap leave it off.
struct AnimeContextMenuItems: View {
    let media: Media
    var onOpenDetails: (() -> Void)?

    @ObservedObject private var aniListAuth = AniListAuthManager.shared
    @ObservedObject private var malAuth = MALAuthManager.shared

    /// The tracking service this title actually belongs to, when there is one signed in.
    private var trackingProvider: MediaProvider? {
        switch media.provider {
        case .mal where malAuth.isLoggedIn: return MALProvider.shared
        case .anilist where aniListAuth.isLoggedIn: return AniListProvider.shared
        default: return nil
        }
    }

    var body: some View {
        Section {
            Text(media.title.displayTitle)

            if let onOpenDetails {
                Button {
                    onOpenDetails()
                } label: {
                    Label("shared.view_details", icon: "list.bullet.below.rectangle")
                }
            }

            if let anilist = AnimeExternalLink.anilist(for: media), let url = anilist.url {
                Link(destination: url) {
                    Label("shared.open_in_anilist", icon: "arrow.up.right.square")
                }
            }

            if let mal = AnimeExternalLink.mal(for: media), let url = mal.url {
                Link(destination: url) {
                    Label("shared.open_in_mal", icon: "arrow.up.right.square")
                }
            }

            if let url = AnimeExternalLink.anilist(for: media)?.url ?? AnimeExternalLink.mal(for: media)?.url {
                if #available(iOS 16.0, macOS 13.0, *) {
                    ShareLink(item: url) {
                        Label("shared.share_anime", icon: "square.and.arrow.up")
                    }
                }
                Button {
                    Clipboard.copy(url.absoluteString)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    ToastManager.shared.show(message: String(localized: "shared.link_copied"), type: .success, duration: 1.6)
                } label: {
                    Label("shared.copy_link", icon: "link")
                }
            } else {
                Button {
                    Clipboard.copy(media.title.displayTitle)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    ToastManager.shared.show(message: String(localized: "shared.title_copied"), type: .success, duration: 1.6)
                } label: {
                    Label("shared.copy_title", icon: "doc.on.doc")
                }
            }
        }

        if let provider = trackingProvider {
            Section {
                statusButton(.planning, label: "library.add_to_watchlist", icon: "text.badge.checkmark")
                statusButton(.current, label: "shared.watching", icon: "play.circle")
                statusButton(.completed, label: "shared.completed", icon: "checkmark.circle")
            } header: {
                Text(String(localized: "library.track_on \(provider.displayName)"))
            }
        }

        // Favourites are AniList's heart, so they take the AniList id — for a MAL-provider
        // title through its mapping, and for an AniList title directly.
        if aniListAuth.isLoggedIn, let favouriteId = anilistFavouriteId {
            Section {
                Button {
                    Task { await toggleFavourite(id: favouriteId) }
                } label: {
                    Label("shared.add_to_favorites", icon: "heart")
                }
            }
        }
    }

    /// The AniList id favourites toggle with: the title's own on an AniList title. A
    /// MAL-provider title's mapping is an asynchronous lookup the menu can't wait on, so
    /// favourites are offered where AniList already knows the id.
    private var anilistFavouriteId: Int? {
        media.provider == .anilist ? media.id : nil
    }

    private func statusButton(_ status: MediaListStatus, label: LocalizedStringKey, icon: String) -> some View {
        Button {
            Task { await setStatus(status) }
        } label: {
            Label(label, icon: icon)
        }
    }

    /// Saves a status with the provider the title belongs to, keeping the progress and
    /// score already on the entry — a status change from a menu must never reset them.
    /// Completing a title moves its progress to everything aired or announced.
    private func setStatus(_ status: MediaListStatus) async {
        guard let provider = trackingProvider else { return }
        let id = media.id
        do {
            let entry = try? await provider.fetchEntry(mediaId: id)
            var progress = entry?.progress ?? 0
            if status == .completed, let aired = media.airedOrAnnouncedEpisodes, aired > progress {
                progress = aired
            }
            try await provider.updateEntry(mediaId: id, status: status, progress: progress, score: entry?.score ?? 0)
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            ToastManager.shared.show(message: String(localized: "library.status_saved \(status.displayName(for: media.isManga ? .manga : .tv))"), type: .success, duration: 1.8)
        } catch {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            ToastManager.shared.show(message: String(localized: "library.status_failed"), type: .error, duration: 2.5)
        }
    }

    private func toggleFavourite(id: Int) async {
        do {
            if media.isManga {
                try await AniListSocialService.shared.toggleFavourite(mangaId: id)
            } else {
                try await AniListSocialService.shared.toggleFavourite(animeId: id)
            }
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            ToastManager.shared.show(message: String(localized: "shared.favorites_updated"), type: .success, duration: 1.6)
        } catch {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            ToastManager.shared.show(message: String(localized: "library.status_failed"), type: .error, duration: 2.5)
        }
    }
}

extension View {
    /// Long-press (right-click on macOS) a title card for the full set of actions: details,
    /// AniList and MyAnimeList, the library statuses, favourites, share, copy link. See
    /// `AnimeContextMenuItems` for what's offered and when.
    @ViewBuilder
    func animeContextMenu(media: Media, onOpenDetails: (() -> Void)? = nil) -> some View {
        #if os(tvOS)
        self
        #else
        self.contextMenu {
            AnimeContextMenuItems(media: media, onOpenDetails: onOpenDetails)
        }
        #endif
    }
}
