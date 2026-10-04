//
//  PlannerCalendarIndex.swift
//  BBNDaily
//
//  HQ-2183. What the calendar needs from the planner, without touching the calendar: which
//  kinds fall on which day (for the dots), and which items fall on a day (for the list under that
//  day's schedule). Pure, so it is unit tested; CalendarVC only asks it questions.
//
//  School-wide key dates (the BB&N key dates PDF, HQ-642) are not read here. `SchoolKeyDateSource`
//  is the one named place they plug in, as read-only items, so the day the PDF reader exists it adds
//  a source and nothing in the calendar changes.
//

import Foundation

/// Something that can say what school-wide dates fall in a range. Implemented later by whatever
/// reads the key dates PDF (HQ-642); nothing implements it yet.
protocol SchoolKeyDateSource {
    /// Items for days from `startDay` through `endDay`, as stored "yyyy-MM-dd" strings. These are
    /// shown to every student and never edited by one, so they must carry a `keyDateIDPrefix` id.
    func keyDates(from startDay: String, through endDay: String) -> [PlannerItem]
}

extension PlannerItem {
    /// Ids of school key dates start with this. A student's own items use Firestore document ids,
    /// which never contain a colon, so the two cannot collide.
    static let keyDateIDPrefix = "keydate:"

    /// A school key date is read-only: the app must not open an editor on it, and a save or delete
    /// of it must never be attempted (there is no document behind it).
    var isSchoolKeyDate: Bool { id.hasPrefix(PlannerItem.keyDateIDPrefix) }
}

struct PlannerCalendarIndex {
    /// The most dots a day shows. FSCalendar draws one per color; past three it stops being a
    /// glanceable mark and starts being clutter that overlaps the date number.
    static let maxDotsPerDay = 3

    private let byDay: [String: [PlannerItem]]

    /// Every item the index holds, for finding an item's parent or steps.
    var allItems: [PlannerItem] { byDay.values.flatMap { $0 } }

    /// - Parameters:
    ///   - items: the student's own items.
    ///   - keyDateSources: where school-wide dates come from. Empty today.
    init(items: [PlannerItem], keyDateSources: [SchoolKeyDateSource] = [], from startDay: String? = nil, through endDay: String? = nil) {
        var all = items
        if let startDay = startDay, let endDay = endDay {
            for source in keyDateSources { all += source.keyDates(from: startDay, through: endDay) }
        }
        self.byDay = Dictionary(grouping: all, by: { $0.dueDate })
    }

    /// The items due on a day, in the same order the Upcoming list uses.
    func items(onDay day: String, today: String) -> [PlannerItem] {
        PlannerListing.ordered(byDay[day] ?? [], today: today)
    }

    /// Distinct kinds on a day, in a fixed order (tests, homework, sports, appointments) so a day's
    /// dots do not shuffle between reloads, capped at `maxDotsPerDay`. A completed item leaves no
    /// dot: the dots say what is still ahead.
    func kinds(onDay day: String) -> [PlannerKind] {
        let open = (byDay[day] ?? []).filter { !$0.completed }
        let present = Set(open.map { $0.kind })
        return Array(PlannerKind.allCases.filter { present.contains($0) }.prefix(PlannerCalendarIndex.maxDotsPerDay))
    }

    /// How many open items are due that day, for accessibility ("2 things due").
    func openCount(onDay day: String) -> Int {
        (byDay[day] ?? []).filter { !$0.completed }.count
    }
}

// MARK: - What to load

/// Where school key dates come from. Empty until something reads the key dates PDF (HQ-642); the
/// calendar already asks, so adding a source there is the only change that day needs.
enum SchoolKeyDates {
    static var sources: [SchoolKeyDateSource] = []
}

/// Which days to read when the calendar shows a page, as stored "yyyy-MM-dd" strings.
enum PlannerCalendarWindow {
    /// What the page itself can show: a month view spans the weeks either side of the month.
    static func needed(forPage page: Date, timeZone: TimeZone = .current) -> (start: String, end: String) {
        window(page, before: 35, after: 42, timeZone: timeZone)
    }

    /// What is read: a good deal wider than needed, so swiping a few months does not read each time.
    static func toLoad(forPage page: Date, timeZone: TimeZone = .current) -> (start: String, end: String) {
        window(page, before: 75, after: 120, timeZone: timeZone)
    }

    /// Whether the days already held include every day that is needed.
    static func covers(_ held: (start: String, end: String), _ needed: (start: String, end: String)) -> Bool {
        held.start <= needed.start && held.end >= needed.end
    }

    private static func window(_ page: Date, before: Int, after: Int, timeZone: TimeZone) -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(byAdding: .day, value: -before, to: page) ?? page
        let end = calendar.date(byAdding: .day, value: after, to: page) ?? page
        return (PlannerItem.dayString(from: start, timeZone: timeZone), PlannerItem.dayString(from: end, timeZone: timeZone))
    }
}
