import Combine
import SwiftUI

/// One episode's scheduled broadcast, or a movie's release, in the app's own media type so the row
/// can use the same artwork rules as everywhere else — Data Saver included.
struct AiringEpisode: Identifiable {
    let media: Media
    /// Nil when the source gives a broadcast slot rather than a numbered episode — MyAnimeList
    /// publishes a weekly time, not "episode 7 airs at…" — and for a movie.
    var episode: Int?
    let airingAt: Date
    /// The last of several episodes released together — a season dropped at once.
    var lastEpisode: Int?
    /// A Simkl show's season.
    var season: Int?
    /// A movie's release: Simkl gives the day, not a time worth showing.
    var isRelease = false
    /// Simkl's popularity rank, 1 the most watched — what a busy day is cut down by.
    var rank: Int?
    /// What "My library" matches against: the media's own id, or Simkl's on a Simkl schedule.
    var libraryID: Int?

    /// Unique per broadcast, not per show — a series can air twice in one week.
    var id: String {
        "\(media.uniqueId)-\(season ?? 0)-\(episode.map(String.init) ?? "")-\(airingAt.timeIntervalSince1970)"
    }

    /// Soonest first, and at the same time — a movie's release day, a network's evening slot —
    /// the most watched first.
    static func soonestFirst(_ a: AiringEpisode, _ b: AiringEpisode) -> Bool {
        if a.airingAt != b.airingAt { return a.airingAt < b.airingAt }
        switch (a.rank, b.rank) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        default: return false
        }
    }

    /// What's airing, under the title.
    var caption: String {
        if isRelease { return String(localized: "home.release") }
        guard let episode else { return String(localized: "home.next_episode") }
        let episodes = lastEpisode.map { String(localized: "home.episodes \(episode) \($0)") } ?? String(localized: "common.episode \(episode)")
        return season.map { String(localized: "home.season \($0) \(episodes)") } ?? episodes
    }
}

/// Simkl's calendar as the Upcoming schedule — no networking, so it's testable.
enum SimklUpcoming {
    /// A day keeps its most watched this many, plus whatever's in the library: Simkl's TV calendar
    /// lists two to three hundred airings a day, most of them local shows from all over the world.
    static let busyDayLength = 40

    /// The airings in `[start, end)`, as rows. A movie counts from the start of its day, since its
    /// time is only Simkl's placeholder. A show's episodes released together are one row.
    static func schedule(_ items: [SimklDiscoverItem], kind: MediaKind, from start: Date, to end: Date,
                         tracker: ProviderType, anilistForMAL: [Int: Int],
                         calendar: Calendar = .current) -> [AiringEpisode] {
        let isRelease = kind == .movie
        let earliest = isRelease ? calendar.startOfDay(for: start) : start
        var rows: [AiringEpisode] = []
        var index: [String: Int] = [:]
        for item in items {
            guard let airsAt = item.airsAt, airsAt >= earliest, airsAt < end,
                  let media = SimklDiscoverMedia.media(item, kind: kind, tracker: tracker, anilistForMAL: anilistForMAL)
            else { continue }
            let key = "\(item.ids.simkl)-\(item.season ?? 0)-\(airsAt.timeIntervalSince1970)"
            if let existing = index[key] {
                // Another episode of the same drop: one row for all of them.
                guard let episode = item.episode, let shown = rows[existing].episode else { continue }
                let first = min(shown, episode)
                let last = max(rows[existing].lastEpisode ?? shown, episode)
                rows[existing].episode = first
                rows[existing].lastEpisode = last > first ? last : nil
                continue
            }
            index[key] = rows.count
            rows.append(AiringEpisode(media: media, episode: isRelease ? nil : item.episode, airingAt: airsAt,
                                      season: isRelease ? nil : item.season, isRelease: isRelease,
                                      rank: item.rank, libraryID: item.ids.simkl))
        }
        return rows
    }

    /// A day's rows cut to its most watched `length`, keeping every one in `library`.
    static func busiest(_ rows: [AiringEpisode], length: Int = busyDayLength, library: Set<Int>) -> [AiringEpisode] {
        guard rows.count > length else { return rows }
        let kept = Set(rows.enumerated()
            .sorted { a, b in
                switch (a.element.rank, b.element.rank) {
                case let (x?, y?) where x != y: return x < y
                case (.some, nil): return true
                case (nil, .some): return false
                default: return a.offset < b.offset
                }
            }
            .prefix(length)
            .map(\.element.id))
        return rows.filter { kept.contains($0.id) || $0.libraryID.map(library.contains) == true }
    }
}

@MainActor
final class UpcomingCalendarViewModel: ObservableObject {
    /// Where the schedule comes from: the tracker's, or Simkl's for one kind while Home is Simkl's.
    enum Source: Hashable {
        case anilist, mal
        case simkl(MediaKind)

        var isSimkl: Bool {
            if case .simkl = self { return true }
            return false
        }
    }

    @Published private(set) var days: [(date: Date, episodes: [AiringEpisode])] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Restrict to shows already in the user's library — the reason most people open a schedule.
    @Published var libraryOnly = false {
        didSet { rebuild() }
    }
    /// Customization's choice of what the schedule opens on: everything, or My Library.
    static let libraryOnlyDefaultKey = "scheduleStartsInLibrary"
    /// Simkl's Anime, Shows or Movies — starting from the one Home shows.
    @Published var simklKind: MediaKind
    let usesSimkl: Bool

    private var all: [AiringEpisode] = []
    private var libraryIDs: Set<Int> = []
    /// The source asked for last; a load for any other has been overtaken.
    private var wanted: Source?

    /// How far ahead to look. A week is what people plan around, and it keeps the request to a
    /// single page.
    private static let window = 7

    init(discovery: DiscoverySource? = nil) {
        let discovery = discovery ?? .shared
        usesSimkl = discovery.usesSimkl
        simklKind = discovery.simklKind
        libraryOnly = (UserDefaults.standard.object(forKey: Self.libraryOnlyDefaultKey) as? Bool) ?? false
    }

    var source: Source {
        if usesSimkl { return .simkl(simklKind) }
        return ProviderManager.shared.primary?.providerType == .mal ? .mal : .anilist
    }

    func load() async {
        let source = source
        if wanted != source {
            // Another kind's schedule never stands in for this one's.
            all = []
            libraryIDs = []
            rebuild()
        }
        wanted = source
        isLoading = true
        errorMessage = nil
        defer { if wanted == source { isLoading = false } }

        do {
            let schedule = try await fetchSchedule(source)
            // Best effort: the schedule is still useful signed out, the filter just isn't.
            let library = await fetchLibraryIDs(source)
            guard wanted == source else { return }
            all = schedule
            libraryIDs = library
            rebuild()
        } catch {
            guard wanted == source else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Whichever schedule the source can give.
    ///
    /// AniList publishes an exact timestamp per episode. MyAnimeList publishes a recurring
    /// weekly slot in Japan Standard Time instead, so its entries are the *next* broadcast of
    /// each airing show rather than a numbered episode — less precise, but the same question
    /// answered, and far better than the feature being invisible on half the accounts. Simkl's
    /// calendar has each airing's time and episode, for shows and movies as well as anime.
    private func fetchSchedule(_ source: Source) async throws -> [AiringEpisode] {
        let start = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: Self.window, to: start) else { return [] }

        switch source {
        case .mal:
            return try await MALOfficialDiscoveryService.shared
                .airingSchedule(within: Self.window)
                .map { entry in
                    AiringEpisode(
                        media: MALOfficialDiscoveryService.shared.mapToMedia(entry.node),
                        episode: nil,
                        airingAt: entry.airsAt
                    )
                }
        case .anilist:
            return try await AniListService.shared.airingSchedule(from: start, to: end).map {
                AiringEpisode(
                    media: AniListProvider.shared.mapMedia($0.media),
                    episode: $0.episode,
                    airingAt: $0.airingAt
                )
            }
        case .simkl(let kind):
            let items = try await SimklFeedStore.shared.items(.calendar(kind))
            let tracker = SimklDiscoverMedia.tracker
            let map = await SimklDiscoverMedia.anilistMap(for: items, kind: kind, tracker: tracker)
            return SimklUpcoming.schedule(items, kind: kind, from: start, to: end,
                                          tracker: tracker, anilistForMAL: map)
        }
    }

    /// The ids "My library" matches: the tracker's media ids, or the Simkl ids of the kind's
    /// Simkl library — the saved copy where there is one, as Simkl asks reads to be rationed.
    private func fetchLibraryIDs(_ source: Source) async -> Set<Int> {
        switch source {
        case .anilist, .mal:
            return Set((try? await ProviderManager.shared.primary?.fetchLibrary())?.map(\.media.id) ?? [])
        case .simkl(let kind):
            let service = SimklLibraryService.shared
            let entries: [LibraryEntry]?
            if let saved = service.cachedLibrary(kind) {
                entries = saved
            } else {
                entries = try? await service.fetchLibrary(kind)
            }
            return Set(entries?.map(\.id) ?? [])
        }
    }

    var canFilterByLibrary: Bool { !libraryIDs.isEmpty }

    private func inLibrary(_ entry: AiringEpisode) -> Bool {
        libraryIDs.contains(entry.libraryID ?? entry.media.id)
    }

    private func rebuild() {
        let visible = libraryOnly ? all.filter(inLibrary) : all
        let grouped = Dictionary(grouping: visible) {
            Calendar.current.startOfDay(for: $0.airingAt)
        }
        let isSimkl = source.isSimkl
        days = grouped
            .map { day in
                // Simkl's days run to hundreds of airings; the trackers' are anime only.
                let rows = isSimkl ? SimklUpcoming.busiest(day.value, library: libraryIDs) : day.value
                return (date: day.key, episodes: rows.sorted(by: AiringEpisode.soonestFirst))
            }
            .sorted { $0.date < $1.date }
    }

    /// What's empty, by what the schedule lists.
    var emptyTitle: String {
        if libraryOnly { return String(localized: "home.nothing_from_your_library") }
        return source == .simkl(.movie) ? String(localized: "home.no_releases") : String(localized: "home.nothing_scheduled")
    }

    var emptyDescription: String {
        let movies = source == .simkl(.movie)
        if libraryOnly {
            return movies ? String(localized: "home.no_movie_youre_following_comes")
                          : String(localized: "home.no_show_youre_following_airs")
        }
        return movies ? String(localized: "home.no_movies_come_out_in") : String(localized: "home.no_episodes_are_scheduled_in")
    }
}

/// A week of upcoming episodes, browsed one day at a time.
///
/// The seven days of the window sit in one continuous row of tabs — weekday and date, a dot
/// on the days with something airing, today outlined — scrollable where they don't fit.
/// The selected day's episodes list below with artwork, time, and whether each has already
/// aired or is still counting down. AniList carries an exact timestamp per episode;
/// MyAnimeList a weekly slot in Japan Standard Time; while Home is Simkl's, the schedule is
/// Simkl's calendar for anime, shows or movies.
struct UpcomingCalendarView: View {
    @StateObject private var vm = UpcomingCalendarViewModel()
    /// The day being browsed; today until the user picks another.
    @State private var selectedDay: Date?

    var body: some View {
        Group {
            if vm.isLoading && vm.days.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = vm.errorMessage, vm.days.isEmpty {
                ContentUnavailableView(
                    "common.couldnt_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if vm.days.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey(vm.emptyTitle),
                    systemImage: "calendar",
                    description: Text(vm.emptyDescription)
                )
            } else {
                scheduleContent
            }
        }
        .navigationTitle("shared.upcoming")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // The condition lives inside the item, not around it: a bare `if` in a toolbar
            // builder needs iOS 16 and this ships to 15.
            ToolbarItem(placement: .principal) {
                if vm.usesSimkl {
                    SimklKindMenu(kind: $vm.simklKind) { String(localized: "home.upcoming \($0.simklKindTitle)") }
                } else {
                    // A Mac shows the navigation title already, at the toolbar's leading edge.
                    #if !os(macOS)
                    Text("shared.upcoming").font(.headline)
                    #endif
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if vm.canFilterByLibrary {
                    Button {
                        vm.libraryOnly.toggle()
                    } label: {
                        Label("common.my_library", icon: vm.libraryOnly ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
        .task(id: vm.simklKind) { await vm.load() }
    }

    // MARK: - Layout

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            weekdayBar
            #if os(iOS)
            Divider().opacity(0.5)
            #endif
            dayList
        }
    }

    /// The seven days of the schedule's window, starting today.
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var effectiveDay: Date { selectedDay ?? weekDays.first ?? Date() }

    private var selectedEntries: [AiringEpisode] {
        vm.days.first { Calendar.current.isDate($0.date, inSameDayAs: effectiveDay) }?.episodes ?? []
    }

    // MARK: - Weekday bar

    private var weekdayBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    dayChip(day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func dayChip(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day, inSameDayAs: effectiveDay)
        let isToday = calendar.isDateInToday(day)
        let count = vm.days.first { calendar.isDate($0.date, inSameDayAs: day) }?.episodes.count ?? 0
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedDay = day }
        } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.weight(.semibold))
                Text(day, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.85) : Color.accentColor)
                    .frame(width: 4, height: 4)
                    .opacity(count > 0 ? 1 : 0)
            }
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.dayLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Day list

    private var dayList: some View {
        List {
            let entries = selectedEntries
            if entries.isEmpty {
                VStack(spacing: 10) {
                    IconView("calendar")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(vm.libraryOnly ? "home.nothing_from_your_library" : "schedule.nothing_this_day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("schedule.try_another_day")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(entries) { entry in
                        NavigationLink {
                            MediaDestination(media: entry.media)
                        } label: {
                            row(entry)
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(Self.dayLabel(for: effectiveDay))
                        Text(effectiveDay, format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .softScrollEdges()
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private func row(_ entry: AiringEpisode) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(urlString: entry.media.coverImage.thumb ?? "")
                .frame(width: 54, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                CardTitle(entry.media.title.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(entry.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                statusChip(entry)
            }

            Spacer(minLength: 0)

            if !entry.isRelease {
                Text(entry.airingAt, style: .time)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .fullTitleContextMenu(entry.media.title.displayTitle)
    }

    /// Whether the broadcast has already happened — an episode that aired an hour ago is
    /// watchable now, one later tonight isn't.
    @ViewBuilder
    private func statusChip(_ entry: AiringEpisode) -> some View {
        if entry.isRelease {
            Label("home.release", icon: "sparkles")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        } else if entry.airingAt <= Date() {
            Label("schedule.aired", icon: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else {
            Label {
                Text(entry.airingAt, style: .relative)
            } icon: {
                IconView("clock")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
    }

    /// "Today" and "Tomorrow" read faster than a date when they apply; everything else gets its
    /// weekday, since a week never repeats one.
    static func dayLabel(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "shared.today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) { return String(localized: "home.tomorrow") }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
