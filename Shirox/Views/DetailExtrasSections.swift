import SwiftUI

// MARK: - Airing information

/// The detail page's airing card: where a title stands right now — status, how many
/// episodes are out, when the next one airs and on what weekday slot — from the metadata
/// AniList publishes. A fact the source doesn't give isn't shown; nothing is invented.
struct AiringInfoSection: View {
    let media: Media

    private var nextDate: Date? {
        media.nextAiringEpisode?.airingAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    private var aired: Int? {
        guard let next = media.nextAiringEpisode?.episode, next > 1 else { return nil }
        return next - 1
    }

    /// What the count line says: "12 of 24 out now" while airing, the start date before
    /// it begins, nothing when there's nothing precise to say.
    private var availabilityLine: String? {
        if let aired, let total = media.episodes, total > 0 {
            return String(localized: "detail.episodes_out_of \(aired) \(total)")
        }
        if media.status == "NOT_YET_RELEASED", let start = media.startDate?.display {
            return String(localized: "detail.starts_on \(start)")
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(media.statusDisplay ?? String(localized: "shared.unknown"))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if let availabilityLine {
                    Text(availabilityLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let episode = media.nextAiringEpisode?.episode {
                HStack(spacing: 10) {
                    IconView("calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("detail.next_episode \(episode)")
                            .font(.subheadline.weight(.medium))
                        if let nextDate {
                            HStack(spacing: 6) {
                                Text(nextDate, format: .dateTime.weekday(.wide).hour().minute())
                                Text(nextDate, style: .relative)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            facts
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    /// What's known beyond the schedule: length, studio, first broadcast. Only rows with
    /// something to say appear.
    @ViewBuilder
    private var facts: some View {
        let rows = factRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.icon) { row in
                    HStack(spacing: 10) {
                        IconView(row.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(row.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 2)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    private struct FactRow {
        let icon: String
        let text: String
    }

    private var factRows: [FactRow] {
        var rows: [FactRow] = []
        if let duration = media.duration, duration > 0 {
            rows.append(FactRow(icon: "clock", text: String(localized: "detail.minutes_per_episode \(duration)")))
        }
        if let studio = media.mainStudio {
            rows.append(FactRow(icon: "building.columns", text: String(localized: "detail.studio \(studio)")))
        }
        if let start = media.startDate?.display {
            rows.append(FactRow(icon: "sparkles", text: String(localized: "detail.first_aired \(start)")))
        }
        return rows
    }

    private var statusColor: Color {
        switch media.status {
        case "RELEASING", "currently_airing": return .green
        case "NOT_YET_RELEASED", "not_yet_aired": return .blue
        case "HIATUS": return .orange
        case "CANCELLED": return .red
        default: return .secondary
        }
    }
}

// MARK: - Seasons

/// The franchise's seasons in order — prequels before this title, sequels after — as one
/// scrollable row, so a viewer steps through a series without guessing which entry is
/// which. The title itself sits outlined in the middle of its chain.
struct SeasonsSection: View {
    let media: Media

    private enum Placement: Equatable {
        case prequel
        case current
        case sequel
    }

    private struct Entry: Identifiable {
        let id: String
        let placement: Placement
        let edge: MediaRelationEdge?
    }

    /// The anime relations that make up a season chain, this title between its prequel and
    /// its sequel.
    private var chain: [Entry] {
        guard let edges = media.relations?.edges else { return [] }
        func isAnime(_ edge: MediaRelationEdge) -> Bool { edge.node.type != "MANGA" }
        var entries: [Entry] = []
        for edge in edges where edge.relationType == "PREQUEL" && isAnime(edge) {
            entries.append(Entry(id: "prequel-\(edge.node.id)", placement: .prequel, edge: edge))
        }
        entries.append(Entry(id: "current", placement: .current, edge: nil))
        for edge in edges where edge.relationType == "SEQUEL" && isAnime(edge) {
            entries.append(Entry(id: "sequel-\(edge.node.id)", placement: .sequel, edge: edge))
        }
        return entries
    }

    var body: some View {
        let entries = chain
        if entries.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("detail.seasons")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(entries) { entry in
                            seasonCard(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private func seasonCard(_ entry: Entry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if let edge = entry.edge {
            NavigationLink {
                AniListDetailView(mediaId: edge.node.id, preloadedMedia: edge.node)
            } label: {
                RelationCard(edge: edge)
                    .frame(width: 128)
                    .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        } else {
            TVDBPosterImage(media: media)
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(width: 128)
                .overlay(shape.strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2))
                .overlay(alignment: .topLeading) {
                    Text("detail.this_season")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                        .padding(8)
                }
                .clipShape(shape)
                .contentShape(shape)
        }
    }
}

// MARK: - More Like This

/// The recommendations row: titles AniList's users recommend for this one, as cards with
/// their score. Only what the API returned — no placeholders, nothing made up.
struct MoreLikeThisSection: View {
    let items: [Media]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("detail.more_like_this")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink {
                                AniListDetailView(mediaId: item.id, preloadedMedia: item)
                            } label: {
                                RecommendationCard(media: item)
                                    .frame(width: 128)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 20)
        }
    }
}

/// One recommended title: poster, title, and its community score when AniList has one.
struct RecommendationCard: View {
    let media: Media

    var body: some View {
        ZStack {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(TVDBPosterImage(media: media).frame(maxWidth: .infinity, maxHeight: .infinity).clipped())
            if let score = media.averageScore, score > 0 {
                HStack(spacing: 3) {
                    IconView("star.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(score)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)
            }
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.92), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .hiddenWithCardTitles()
        }
        .overlay(alignment: .bottomLeading) {
            CardTitle(media.title.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .hiddenWithCardTitles()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .fullTitleContextMenu(media.title.displayTitle)
    }
}

// MARK: - Follow button

/// Follows the title for release notifications, right from its page. A bell next to the
/// Watch button; filled while following.
struct FollowButton: View {
    let media: Media

    @ObservedObject private var store = FollowedSeriesStore.shared

    private var isFollowing: Bool { store.isFollowing(media) }

    var body: some View {
        Button(action: toggle) {
            IconView(isFollowing ? "bell.fill" : "bell")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFollowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(isFollowing ? String(localized: "detail.unfollow_title") : String(localized: "detail.follow_title"))
    }

    private func toggle() {
        let title = media.title.displayTitle
        if store.toggle(media) {
            #if os(iOS)
            ToastManager.shared.show(message: String(localized: "detail.now_following \(title)"), type: .success)
            #endif
            // Asks for notification permission and schedules the next episode's reminder.
            Task { await EpisodeReleaseNotifier.shared.checkNow(force: true) }
        } else {
            let id = FollowedSeries(media: media).id
            Task { await EpisodeReleaseNotifier.shared.cancel(seriesID: id) }
        }
    }
}
