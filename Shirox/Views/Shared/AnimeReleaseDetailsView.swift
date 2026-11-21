import SwiftUI
import UserNotifications

/// The release details a row carries into the shared page: whichever of the airing facts
/// the source gave. Both the Schedule's rows and the Notifications page's followed series
/// build one, so the two open the same page with the same actions.
struct AnimeReleaseContext: Identifiable {
    let media: Media
    /// The number of the next broadcast, when the source publishes one.
    var episode: Int?
    /// When the next broadcast (or a movie's release) airs; nil when unknown.
    var airingAt: Date?
    /// A movie's release day, which has no episode number worth showing.
    var isRelease: Bool

    var id: String { "\(media.provider.rawValue)-\(media.id)-\(episode ?? 0)-\(airingAt?.timeIntervalSince1970 ?? 0)" }

    /// From the Schedule's row.
    init(_ entry: AiringEpisode) {
        media = entry.media
        episode = entry.episode
        airingAt = entry.airingAt
        isRelease = entry.isRelease
    }

    /// From a followed series on the Notifications page.
    init(_ entry: FollowedSeries) {
        media = entry.media
        episode = entry.nextEpisode
        airingAt = entry.nextAiringAt
        isRelease = false
    }

    /// From bare media — a page that knows a title is airing but has no row payload.
    init(media: Media) {
        self.media = media
        episode = media.nextAiringEpisode?.episode
        airingAt = media.nextAiringEpisode?.airingAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        isRelease = false
    }
}

/// The one release-details page the Schedule and Notifications both open: the broadcast's
/// live countdown above the artwork and title, the facts the source actually publishes,
/// and the actions the app already supports — follow, reminder, copy name, share, and the
/// way into the full anime page. A fact the source doesn't give is hidden, never invented:
/// no Unknown placeholders, no fabricated dates.
struct AnimeReleaseDetailsView: View {
    let context: AnimeReleaseContext

    /// The full record behind the row, refetched on arrival: the row's payload can be as
    /// thin as a title and a cover, and the page needs the airing status and the next
    /// broadcast's timestamp to be more than a poster.
    @State private var full: Media?
    @State private var loadFailed = false
    /// The tracker's entry, when the account is signed in — the tracking line.
    @State private var entry: LibraryEntry?
    /// The followed state, observed live so the follow button keeps the store's answer.
    @ObservedObject private var follows = FollowedSeriesStore.shared
    @ObservedObject private var notifier = EpisodeReleaseNotifier.shared
    @State private var notificationPermission: UNAuthorizationStatus?
    @Environment(\.openURL) private var openURL

    private var media: Media { full ?? context.media }
    private var isFollowing: Bool { follows.isFollowing(media) }

    /// The countdown's moment: the row's own timestamp while it is the only one known,
    /// then the refetched record's — whichever is real right now.
    private var nextAiringAt: Date? {
        if let next = full?.nextAiringEpisode, let seconds = next.airingAt,
           TimeInterval(seconds) > Date().timeIntervalSince1970 {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if let airingAt = context.airingAt, airingAt > Date() { return airingAt }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                countdownCard
                factsCard
                trackingCard
                actionsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .softScrollEdges()
        .background(background.ignoresSafeArea())
        .navigationTitle(media.title.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: context.id) { await load() }
        .task { notificationPermission = await notifier.authorizationStatus }
    }

    private var background: Color {
        #if os(tvOS)
        return Color.clear
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }

    // MARK: - Load

    private func load() async {
        loadFailed = false
        do {
            let provider = media.provider
            let fetched = try await ProviderManager.shared.call { try await $0.detail(id: media.id) }
            // The answer must be the same title's: a provider that fell back mid-flight
            // could answer with the other service's id-space.
            if fetched.provider == provider || fetched.id == media.id {
                full = fetched
            }
            if AniListAuthManager.shared.isLoggedIn || MALAuthManager.shared.isLoggedIn {
                entry = try? await ProviderManager.shared.call { try await $0.fetchEntry(mediaId: media.id) }
            }
        } catch {
            loadFailed = true
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 14) {
            CachedAsyncImage(urlString: media.coverImage.best ?? "")
                .frame(width: 96, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                CardTitle(media.title.displayTitle)
                    .font(.title3.weight(.heavy))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let status = full?.statusDisplay ?? media.statusDisplay {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: 7, height: 7)
                        Text(status)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if let score = full?.averageScore ?? media.averageScore {
                    Label("\(score)%", icon: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var statusTint: Color {
        switch media.status {
        case "RELEASING", "currently_airing": return .green
        case "NOT_YET_RELEASED", "not_yet_aired": return .blue
        case "HIATUS": return .orange
        case "CANCELLED": return .red
        default: return .secondary
        }
    }

    // MARK: - Countdown

    /// The live countdown, only when a reliable future broadcast exists. No upcoming
    /// episode: the whole card folds away — never "Unknown", never a zeroed clock.
    @ViewBuilder
    private var countdownCard: some View {
        if let nextAiringAt {
            VStack(alignment: .leading, spacing: 12) {
                if !context.isRelease, let episode = full?.nextAiringEpisode?.episode ?? context.episode {
                    Text("release.next_episode \(episode)")
                        .font(.subheadline.weight(.semibold))
                } else if context.isRelease {
                    Text("home.release")
                        .font(.subheadline.weight(.semibold))
                }

                LiveCountdownView(target: nextAiringAt)

                HStack(spacing: 6) {
                    IconView("calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(nextAiringAt, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Facts

    /// What the source publishes beyond the schedule. A row with no answer keeps its card
    /// quiet — nothing here says Unknown.
    @ViewBuilder
    private var factsCard: some View {
        let rows = factRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 10) {
                        IconView(row.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(row.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    private struct FactRow { let icon: String; let text: String }

    private var factRows: [FactRow] {
        var rows: [FactRow] = []
        if let episodes = full?.episodes ?? media.episodes, episodes > 0 {
            rows.append(FactRow(icon: "list.number", text: String(localized: "release.total_episodes \(episodes)")))
        }
        if let genres = full?.genres ?? media.genres, !genres.isEmpty {
            rows.append(FactRow(icon: "tag", text: genres.prefix(4).joined(separator: " · ")))
        }
        if let duration = full?.duration, duration > 0 {
            rows.append(FactRow(icon: "clock", text: String(localized: "detail.minutes_per_episode \(duration)")))
        }
        return rows
    }

    // MARK: - Tracking

    /// The signed-in account's own record of this title: status, progress, score. Signed
    /// out, or the tracker knows nothing: the card doesn't appear at all.
    @ViewBuilder
    private var trackingCard: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 8) {
                Text("release.tracking")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(entry.status.displayName(for: .tv))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if entry.progress > 0 {
                        Text("release.tracked_progress \(entry.progress)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if entry.score > 0 {
                        Label(String(entry.score), icon: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 10) {
            NavigationLink {
                MediaDestination(media: media)
            } label: {
                solidRowLabel(Text("release.open_anime_details"), icon: "arrow.up.right.square")
            }
            .buttonStyle(ReleaseRowPressStyle())

            followButton

            reminderButton

            nextUnwatchedButton

            Button { copyName() } label: {
                solidRowLabel(Text("shared.copy_title"), icon: "doc.on.doc")
            }
            .buttonStyle(ReleaseRowPressStyle())

            shareButton
        }
    }

    private func solidRowLabel(_ label: Text, icon: String) -> some View {
        HStack(spacing: 10) {
            IconView(icon)
                .font(.subheadline.weight(.semibold))
            label
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            solidRowLabel(
                Text(isFollowing ? "release.unfollow" : "release.follow"),
                icon: isFollowing ? "bell.slash" : "bell.fill"
            )
            .foregroundStyle(isFollowing ? Color.secondary : Color.primary)
        }
        .buttonStyle(ReleaseRowPressStyle())
    }

    /// The reminder: following is what schedules the app's own episode notification, so
    /// the row mirrors the follow state — plus the system permission the banner already
    /// asks for, requested the moment a follow turns on. Not offered where the platform
    /// has no notifications.
    @ViewBuilder
    private var reminderButton: some View {
        if isFollowing, let permission = notificationPermission {
            Button {
                Task { await requestReminderPermission() }
            } label: {
                solidRowLabel(
                    Text(reminderLabel(for: permission)),
                    icon: reminderIcon(for: permission)
                )
            }
            .buttonStyle(ReleaseRowPressStyle())
        }
    }

    private func reminderLabel(for permission: UNAuthorizationStatus) -> LocalizedStringKey {
        switch permission {
        case .authorized, .provisional, .ephemeral: return "release.reminder_on"
        case .denied: return "notifications.open_system_settings"
        default: return "notifications.turn_on"
        }
    }

    private func reminderIcon(for permission: UNAuthorizationStatus) -> String {
        switch permission {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        default: return "bell.badge"
        }
    }

    /// The user's own next unwatched episode, where the tracker account has one: pushes
    /// the full details page, where playback lives. Not signed in, or nothing behind:
    /// no row.
    @ViewBuilder
    private var nextUnwatchedButton: some View {
        if let progress = entry?.progress, progress > 0 {
            NavigationLink {
                MediaDestination(media: media)
            } label: {
                solidRowLabel(
                    Text("release.continue_episode \(progress + 1)"),
                    icon: "play.circle"
                )
            }
            .buttonStyle(ReleaseRowPressStyle())
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url = AnimeExternalLink.anilist(for: media)?.url ?? AnimeExternalLink.mal(for: media)?.url {
            if #available(iOS 16.0, macOS 13.0, *) {
                ShareLink(item: url) {
                    solidRowLabel(Text("shared.share_anime"), icon: "square.and.arrow.up")
                }
                .buttonStyle(ReleaseRowPressStyle())
            } else {
                AnchoredShareButton(items: [url.absoluteString], label: {
                    solidRowLabel(Text("shared.share_anime"), icon: "square.and.arrow.up")
                })
            }
        }
    }

    // MARK: - Actions' bodies

    private func copyName() {
        Clipboard.copy(media.title.displayTitle)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        ToastManager.shared.show(message: String(localized: "shared.title_copied"), type: .success, duration: 1.6)
    }

    private func toggleFollow() {
        let nowFollowing = follows.toggle(media)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        if nowFollowing {
            Task {
                await notifier.requestPermissionIfNeeded()
                notificationPermission = await notifier.authorizationStatus
                await notifier.checkNow()
            }
            ToastManager.shared.show(message: String(localized: "release.following_toast"), type: .success, duration: 1.8)
        }
    }

    private func requestReminderPermission() async {
        if notificationPermission == .denied {
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            #endif
            return
        }
        _ = await notifier.requestPermissionIfNeeded()
        notificationPermission = await notifier.authorizationStatus
    }
}

/// The page's row press: the same small spring the rest of the app's rows lean into.
private struct ReleaseRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
