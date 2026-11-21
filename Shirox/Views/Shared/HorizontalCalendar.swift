import SwiftUI

#if os(iOS)
/// One day of the paged calendar. Identity is per instance: a week replaced while paging is a
/// new set of days to the scroll view, which is what keeps the jump from being a visible jump.
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date

    var dayValue: Int { Calendar.current.component(.day, from: date) }
    var weekdaySymbol: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols[Calendar.current.component(.weekday, from: date) - 1]
    }
}

/// One calendar week of the paged calendar's three-week window.
struct CalendarWeek: Identifiable {
    let id = UUID()
    let days: [CalendarDay]

    /// The week `offset` weeks away from the one containing `date`, as its seven days.
    static func containing(_ date: Date, offsetBy offset: Int, calendar: Calendar = .current) -> CalendarWeek {
        let anchor = calendar.date(byAdding: .weekOfMonth, value: offset, to: date) ?? date
        let start = calendar.dateInterval(of: .weekOfMonth, for: anchor)?.start ?? anchor
        let days = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start).map(CalendarDay.init(date:))
        }
        return CalendarWeek(days: days)
    }
}

/// A calendar that pages one week at a time, without end in either direction, the way the
/// system's own calendars do. Ported from the reference project's HCalendarView.
///
/// Three weeks live in the scroll view; when paging reaches either edge, the two weeks beyond
/// it are inserted and the two at the far end dropped. The swap is hidden by locking the week
/// on screen in place for the frame it takes to scroll the window back to the middle, velocity
/// preserved. `date` follows the paging to the same weekday of the week paged to.
@available(iOS 18.0, *)
struct HorizontalCalendar<Content: View>: View {
    /// Whether paging moves `date` along; a screen with its own idea of the selection turns
    /// this off and takes the tap alone.
    var updatesDateOnScroll = true
    @Binding var date: Date
    @ViewBuilder var content: (CalendarDay) -> Content

    @State private var weeks: [CalendarWeek]
    @State private var scrollPosition = ScrollPosition()
    @State private var containerSize = CGSize.zero
    @State private var isLocked = false
    @State private var lockedID: CalendarWeek.ID?
    /// The view starts on the middle week.
    @State private var weekIndex = 1
    /// True while the window is recentring on an outside date change, so the week-follow
    /// doesn't rewrite the just-set selection in that frame.
    @State private var isRecentering = false
    private let calendar = Calendar.current

    init(updatesDateOnScroll: Bool = true,
         date: Binding<Date>,
         @ViewBuilder content: @escaping (CalendarDay) -> Content) {
        self.updatesDateOnScroll = updatesDateOnScroll
        self._date = date
        self.content = content
        weeks = (-1...1).map { CalendarWeek.containing(date.wrappedValue, offsetBy: $0) }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(weeks) { week in
                    HStack(spacing: 0) {
                        ForEach(week.days) { day in
                            content(day)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .visualEffect { [isLocked, lockedID] content, proxy in
                        // While the window jumps back to the middle, every week but the one
                        // on screen is hidden and that one is pinned where it already was.
                        let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
                        return content
                            .opacity(isLocked ? (lockedID == week.id ? 1 : 0) : 1)
                            .offset(x: isLocked ? -minX : 0)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.center, for: .initialOffset)
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            containerSize = newValue
        }
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.x + $0.contentInsets.leading
        } action: { _, newValue in
            guard containerSize.width != 0 else { return }
            weekIndex = Int((newValue / containerSize.width).rounded())

            // Paged past either edge: two new weeks go in, the two at the far end come out,
            // and the array stays three long.
            let addPreviousWeeks = newValue < 0
            let addNextWeeks = newValue > containerSize.width * 2
            if addPreviousWeeks || addNextWeeks, !isLocked,
               let firstWeekDate = weeks.first?.days.first?.date,
               let lastWeekDate = weeks.last?.days.first?.date {
                let insert: [CalendarWeek] = addPreviousWeeks
                    ? [-2, -1].map { CalendarWeek.containing(firstWeekDate, offsetBy: $0) }
                    : [1, 2].map { CalendarWeek.containing(lastWeekDate, offsetBy: $0) }
                lockedID = (addPreviousWeeks ? weeks.first : weeks.last)?.id
                isLocked = true
                if addPreviousWeeks {
                    weeks.insert(contentsOf: insert, at: 0)
                    weeks.removeLast(2)
                } else {
                    weeks.append(contentsOf: insert)
                    weeks.removeFirst(2)
                }
            } else if isLocked {
                var transaction = Transaction()
                transaction.scrollPositionUpdatePreservesVelocity = true
                withTransaction(transaction) {
                    if addPreviousWeeks {
                        scrollPosition.scrollTo(x: containerSize.width * 2)
                    } else {
                        scrollPosition.scrollTo(x: -containerSize.width * 2)
                    }
                }
                // A turn of the run loop, or the jump shows as a flicker.
                DispatchQueue.main.async {
                    isLocked = false
                    lockedID = nil
                }
            }
        }
        .onAppear {
            if weeks.indices.contains(1) {
                scrollPosition.scrollTo(id: weeks[1].id)
            }
        }
        .onChange(of: weekIndex) { _, newValue in
            // Paging lands on the same weekday of the week paged to.
            guard !isRecentering, updatesDateOnScroll, weeks.indices.contains(newValue) else { return }
            let symbolIndex = calendar.component(.weekday, from: date) - 1
            if weeks[newValue].days.indices.contains(symbolIndex) {
                date = weeks[newValue].days[symbolIndex].date
            }
        }
        .onChange(of: date) { _, newDate in
            // The date changed from outside the calendar — the schedule's SceneStorage
            // restoring a picked day, another control moving the selection. If the new day
            // sits in a week the window isn't showing, the window recentres on it and the
            // visible week follows the day again — the list and the selector stay one
            // state. A day within the shown week changes nothing: the cells read the
            // selection straight from the binding.
            guard let shownWeek = weeks.indices.contains(weekIndex) ? weeks[weekIndex].days.first?.date : nil,
                  Self.weekStart(of: newDate) != Self.weekStart(of: shownWeek) else { return }
            isRecentering = true
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                weeks = (-1...1).map { CalendarWeek.containing(newDate, offsetBy: $0) }
                weekIndex = 1
                if weeks.indices.contains(1) {
                    scrollPosition.scrollTo(id: weeks[1].id)
                }
            }
            DispatchQueue.main.async { isRecentering = false }
        }
    }

    /// The week a day belongs to, for comparing windows without their times.
    private static func weekStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfMonth, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
#endif
