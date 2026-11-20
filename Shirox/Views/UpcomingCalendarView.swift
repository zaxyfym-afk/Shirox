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

    /// Each day's rows, keyed by the day's start, the library filter applied. A day nothing
    /// airs on is absent, so the dots say "nothing" and the list says it in words.
    @Published private(set) var days: [Date: [AiringEpisode]] = [:]
    /// The calendar weeks already asked of the source, so paging back and forth costs nothing.
    @Published private(set) var loadedWeeks: Set<Date> = []
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

    private var allByDay: [Date: [AiringEpisode]] = [:]
    private var libraryIDs: Set<Int> = []
    /// The source asked for last; a load for any other has been overtaken.
    private var wanted: Source?
    /// Weeks a fetch is in flight for.
    private var pendingWeeks: Set<Date> = []

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

    /// The day the schedule opens on: the week it sits in is the one asked for first.
    func load() async {
        let source = source
        if wanted != source {
            // Another kind's schedule never stands in for this one's.
            allByDay = [:]
            libraryIDs = []
            loadedWeeks = []
            pendingWeeks = []
            rebuild()
        }
        wanted = source
        isLoading = true
        errorMessage = nil
        defer { if wanted == source { isLoading = false } }

        do {
            try await loadWeek(containing: Date(), source: source)
            // Best effort: the schedule is still useful signed out, the filter just isn't.
            let library = await fetchLibraryIDs(source)
            guard wanted == source else { return }
            libraryIDs = library
            rebuild()
        } catch {
            guard wanted == source else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Pull to refresh: the weeks asked for go back to none and today's comes again, the rows
    /// on screen staying until each week's replacement lands.
    func refresh() async {
        loadedWeeks = []
        await load()
    }

    /// Loads the calendar week holding `date` if it hasn't been already. The fetch is
    /// unstructured on purpose: a fast swipe through weeks shouldn't cancel the one behind it.
    func ensureWeekLoaded(containing date: Date) {
        // Simkl's calendar is one rationed feed that came with the first load; weeks beyond
        // what it holds are empty, not worth asking again.
        guard !usesSimkl else { return }
        let weekStart = Self.weekStart(containing: date)
        guard !loadedWeeks.contains(weekStart), !pendingWeeks.contains(weekStart) else { return }
        pendingWeeks.insert(weekStart)
        let source = source
        Task { [weak self] in
            await self?.fetchWeek(weekStart, source: source)
        }
    }

    /// The rows of one day, as filtered.
    func episodes(on date: Date) -> [AiringEpisode] {
        days[Calendar.current.startOfDay(for: date)] ?? []
    }

    /// Whether the calendar week holding `date` has been asked of the source — a day in a
    /// week not yet asked says "not loaded", not "nothing".
    func isWeekLoaded(containing date: Date) -> Bool {
        loadedWeeks.contains(Self.weekStart(containing: date))
    }

    var canFilterByLibrary: Bool { !libraryIDs.isEmpty }

    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfMonth, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func fetchWeek(_ weekStart: Date, source: Source) async {
        guard let interval = Calendar.current.dateInterval(of: .weekOfMonth, for: weekStart) else { return }
        do {
            let rows = try await fetchSchedule(source, from: interval.start, to: interval.end)
            guard wanted == source else { return }
            merge(rows)
            loadedWeeks.insert(weekStart)
        } catch {
            // A week that failed counts as asked: an error per swipe would nag, and the pull
            // to refresh is the way back.
            loadedWeeks.insert(weekStart)
        }
        pendingWeeks.remove(weekStart)
    }

    private func loadWeek(containing date: Date, source: Source) async throws {
        let weekStart = Self.weekStart(containing: date)
        guard let interval = Calendar.current.dateInterval(of: .weekOfMonth, for: date) else { return }
        pendingWeeks.insert(weekStart)
        defer { pendingWeeks.remove(weekStart) }
        let rows = try await fetchSchedule(source, from: interval.start, to: interval.end)
        guard wanted == source else { return }
        merge(rows)
        loadedWeeks.insert(weekStart)
    }

    /// Whichever schedule the source can give for a window.
    ///
    /// AniList publishes an exact timestamp per episode, so any window can be asked for, past
    /// weeks included. MyAnimeList publishes a recurring weekly slot in Japan Standard Time
    /// instead, so its entries are the *next* broadcast of each airing show from now — a
    /// window is one ranking ask reaching to its end, and before now there is nothing to ask
    /// for. Simkl's calendar has each airing's time and episode, for shows and movies as well
    /// as anime.
    private func fetchSchedule(_ source: Source, from start: Date, to end: Date) async throws -> [AiringEpisode] {
        switch source {
        case .mal:
            guard end > Date() else { return [] }
            let days = max(1, Int(end.timeIntervalSinceNow / 86_400) + 2)
            return try await MALOfficialDiscoveryService.shared
                .airingSchedule(within: days)
                .filter { $0.airsAt >= start && $0.airsAt < end }
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

    private func inLibrary(_ entry: AiringEpisode) -> Bool {
        libraryIDs.contains(entry.libraryID ?? entry.media.id)
    }

    /// Files the rows under their days, Simkl's busy days cut to their most watched.
    private func merge(_ rows: [AiringEpisode]) {
        let isSimkl = source.isSimkl
        let grouped = Dictionary(grouping: rows) { Calendar.current.startOfDay(for: $0.airingAt) }
        for (day, dayRows) in grouped {
            let cut = isSimkl ? SimklUpcoming.busiest(dayRows, library: libraryIDs) : dayRows
            allByDay[day] = cut.sorted(by: AiringEpisode.soonestFirst)
        }
        rebuild()
    }

    private func rebuild() {
        days = allByDay.mapValues { rows in
            libraryOnly ? rows.filter(inLibrary) : rows
        }
    }
}

/// The upcoming schedule, browsed a week at a time on a paged calendar (the system's own
/// calendars' way, from iOS 18) or, before that and on the Mac and Apple TV, one row of tabs
/// for the week ahead.
///
/// Each calendar week is asked of the source as the browsing reaches it, so the schedule runs
/// without end in either direction; the selected day's episodes list below with artwork,
/// time, and whether each has already aired or is still counting down. AniList carries an
/// exact timestamp per episode; MyAnimeList a weekly slot in Japan Standard Time; while Home
/// is Simkl's, the schedule is Simkl's calendar for anime, shows or movies.
struct UpcomingCalendarView: View {
    @StateObject private var vm = UpcomingCalendarViewModel()
    /// The day being browsed; today until the user picks another, and it survives the page
    /// being pushed again.
    @SceneStorage("scheduleSelectedDay") private var storedDay: Double?

    private var effectiveDay: Date {
        let calendar = Calendar.current
        return storedDay.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) }
            ?? calendar.startOfDay(for: Date())
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.days.isEmpty && vm.loadedWeeks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = vm.errorMessage, vm.days.isEmpty, vm.loadedWeeks.isEmpty {
                ContentUnavailableView(
                    "common.couldnt_load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
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
                    // From iOS 18 the paged calendar names the month, as the system's own
                    // calendars do; before it the bar keeps the page's name.
                    if #available(iOS 18, *) {
                        Text(effectiveDay, format: .dateTime.month(.wide).year())
                            .font(.headline)
                    } else {
                        Text("shared.upcoming").font(.headline)
                    }
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
        // Reaching a week the source hasn't been asked for loads it.
        .task(id: effectiveDay) { vm.ensureWeekLoaded(containing: effectiveDay) }
    }

    // MARK: - Layout

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if #available(iOS 18, *) {
                HorizontalCalendar(date: selection) { day in
                    dayCell(day.date)
                }
                .padding(.top, 6)
                .padding(.bottom, 8)
                todayButton
                Divider().opacity(0.5)
            } else {
                weekdayBar
                Divider().opacity(0.5)
            }
            #else
            weekdayBar
            #endif
            dayList
        }
    }

    /// The selection the calendar pages and the cells write to.
    private var selection: Binding<Date> {
        Binding {
            effectiveDay
        } set: { day in
            storedDay = day.timeIntervalSince1970
        }
    }

    /// Back to today from wherever the browsing has gone; hidden while it's already here.
    @ViewBuilder
    private var todayButton: some View {
        if !Calendar.current.isDateInToday(effectiveDay) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    storedDay = Date().timeIntervalSince1970
                }
            } label: {
                Label("shared.today", icon: "calendar")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// One day of the paged calendar: weekday and date, a dot when something airs, today
    /// ringed, the selection filled.
    @available(iOS 18.0, *)
    private func dayCell(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day, inSameDayAs: effectiveDay)
        let isToday = calendar.isDateInToday(day)
        let count = vm.episodes(on: day).count
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                storedDay = day.timeIntervalSince1970
            }
        } label: {
            VStack(spacing: 6) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(day, format: .dateTime.day())
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white : .primary)
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .overlay {
                        if isToday && !isSelected {
                            Circle().strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
                        }
                    }
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.85) : Color.accentColor)
                    .frame(width: 4, height: 4)
                    .opacity(count > 0 ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .animation(.smooth(duration: 0.3), value: effectiveDay)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.dayLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The seven days ahead, for the layouts without the paged calendar.
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
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
        let count = vm.episodes(on: day).count
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                storedDay = day.timeIntervalSince1970
            }
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
            let entries = vm.episodes(on: effectiveDay)
            if !vm.isWeekLoaded(containing: effectiveDay), entries.isEmpty {
                // A week the browsing has reached but the source hasn't answered yet.
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 48)
                .listRowBackground(Color.clear)
            } else if entries.isEmpty {
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
        .morphingRefreshable { await vm.refresh() }
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
        .animeContextMenu(media: entry.media)
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
