//
//  PlannerWeek.swift
//  BBNDaily
//
//  HQ-2184. The weekly game plan, as data: five school days, each with the classes meeting that
//  day, what the student has planned for it, and a plain signal of how heavy it is. Pure, so it is
//  unit tested; the screen only draws what this returns.
//
//  What a day's classes ARE is not decided here. The caller passes a resolver, and in the app that
//  is `resolveDay(date:)`, the one resolver the calendar, notifications and Tasks already use, so a
//  rotating schedule, a special day or a no-school day is right here for the same reason it is
//  right everywhere else. This file only arranges what it is handed.
//
//  There is no auto-scheduling and no suggested plan. The plan is what the student entered;
//  spreading a big deadline across days is the mini-deadlines ticket (HQ-2187).
//

import Foundation

struct WeekClass: Equatable {
    var block: String
    var subject: String
    /// A block the student has free that day (marked Free, or a class that does not meet that weekday). It
    /// is a place to plan something rather than a class, so any kind of item can sit on it.
    var isFree: Bool = false
}

/// What the resolver says about one calendar day.
struct WeekDayInfo: Equatable {
    var weekdayName: String
    /// The student's own classes meeting that day, Free blocks already left out.
    var classes: [WeekClass]
    /// Why there are no classes ("No Class - Enjoy your weekend", a break), or nil on a normal day.
    var emptyMessage: String?
}

struct PlannerWeekDay: Equatable {
    /// "yyyy-MM-dd"
    var day: String
    var info: WeekDayInfo
    /// In the same order the Upcoming list uses.
    var items: [PlannerItem]

    /// Open tests and big deadlines: the things that make a day heavy. Homework and appointments
    /// do not, however many there are, and a completed item no longer counts. This is a count the
    /// student can check against the list, not a score. A step is part of its deadline, not a
    /// second one, even though it carries the deadline's kind.
    var heavyCount: Int {
        items.filter { !$0.completed && $0.parentId == nil && ($0.kind == .test || $0.isBig) }.count
    }

    /// "1 test or deadline" / "3 tests or deadlines", or nil on a day with none.
    var heavyLabel: String? {
        switch heavyCount {
        case 0: return nil
        case 1: return "1 test or deadline"
        default: return "\(heavyCount) tests or deadlines"
        }
    }

    var hasNothingPlanned: Bool { items.isEmpty }

    /// Whether an item shows as a badge on its class's row instead of in the list below it (HQ-2194).
    ///
    /// Only a test or homework, only with a class attached, and only if that class is actually on this
    /// day's schedule. Sports and appointments are not about a class and stay in the list, and so does
    /// anything whose class is not meeting that day (due on a day it doesn't meet, a no-school day):
    /// otherwise it would have nowhere to be shown and would silently disappear.
    ///
    /// A step (HQ-2187) is never badged: it belongs under its test in the Upcoming list, where its
    /// parent counts "2 of 4 steps done". Badged away, a step due tomorrow would leave its test and
    /// the count would drop.
    ///
    /// A Free block (`freeBlocks`) takes an item of any kind attached to it: a meeting, study time, a game.
    static func showsOnClassRow(_ item: PlannerItem, classBlocks: Set<String>, freeBlocks: Set<String> = []) -> Bool {
        guard item.parentId == nil, let block = item.classBlock?.uppercased() else { return false }
        if freeBlocks.contains(block) { return true }
        guard classBlocks.contains(block) else { return false }
        return item.kind == .test || item.kind == .homework
    }

    private var classBlocks: Set<String> { Set(info.classes.filter { !$0.isFree }.map { $0.block.uppercased() }) }
    private var freeBlocks: Set<String> { Set(info.classes.filter { $0.isFree }.map { $0.block.uppercased() }) }

    /// `items` without the ones `badgedItems` puts on a class row for `day`, given the classes being
    /// drawn. The Tomorrow view lists what is left under "Upcoming", so an item is on its class or in
    /// the list, never both. Uses `badgedItems` itself, so the two cannot disagree.
    static func withoutBadged(_ items: [PlannerItem], day: String, classBlocks: [String]) -> [PlannerItem] {
        let badged = Set(classBlocks.flatMap { badgedItems(block: $0, day: day, in: items).map { $0.id } })
        return items.filter { !badged.contains($0.id) }
    }

    /// The items to badge on one class's row for `day` (HQ-2194), from any list of items. The Tomorrow
    /// view calls this too, so "what goes on a class row" is decided here and nowhere else. The class
    /// is taken to be meeting (the caller only asks about rows it is drawing), so only the day, the
    /// block and the kind are checked. Tests before homework, otherwise the order given.
    static func badgedItems(block: String, day: String, in items: [PlannerItem], isFree: Bool = false) -> [PlannerItem] {
        let upper = block.uppercased()
        let matching = items.filter {
            $0.dueDate == day && $0.classBlock?.uppercased() == upper
                && showsOnClassRow($0, classBlocks: isFree ? [] : [upper], freeBlocks: isFree ? [upper] : [])
        }
        // Tests, then homework, then anything else (a Free block's meetings and games), each in the order given.
        return matching.filter { $0.kind == .test } + matching.filter { $0.kind == .homework }
            + matching.filter { $0.kind != .test && $0.kind != .homework }
    }

    /// The items to badge on the row for `block`: tests before homework, then in the order the day
    /// already has them. Finished ones are included, so ticking something off doesn't make it jump
    /// to a different place.
    func itemsOnClassRow(_ block: String) -> [PlannerItem] {
        // Only if that class is on this day's schedule: otherwise the item belongs in the list below.
        let upper = block.uppercased()
        guard classBlocks.contains(upper) || freeBlocks.contains(upper) else { return [] }
        return PlannerWeekDay.badgedItems(block: block, day: day, in: items, isFree: freeBlocks.contains(upper))
    }

    /// One row of a day's section.
    enum Row: Equatable {
        case schoolClass(WeekClass)
        /// Why there are no classes ("No Class - Columbus Day").
        case note(String)
        case item(PlannerItem)
    }

    /// The day's classes first, or the reason there are none, then what is planned. A day with no
    /// classes and no stated reason (the resolver had nothing to say) simply has no class rows.
    var rows: [Row] {
        var rows = [Row]()
        if info.classes.isEmpty {
            if let message = info.emptyMessage { rows.append(.note(message)) }
        } else {
            rows += info.classes.map { .schoolClass($0) }
        }
        // Items badged on a class row are not repeated below it. Every item is in exactly one place.
        let badged = classBlocks, free = freeBlocks
        rows += items.filter { !PlannerWeekDay.showsOnClassRow($0, classBlocks: badged, freeBlocks: free) }.map { .item($0) }
        return rows
    }
}

enum PlannerWeek {

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The Monday of the school week to show for `date`: this week's Monday on a weekday, and NEXT
    /// week's on a Saturday or Sunday, because on a weekend this week is over and what the student
    /// needs is the one coming.
    static func monday(for date: Date, timeZone: TimeZone = .current) -> Date {
        let cal = calendar(timeZone)
        let start = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: start)   // Sunday 1 ... Saturday 7
        let offset: Int
        switch weekday {
        case 1: offset = 1             // Sunday -> tomorrow
        case 7: offset = 2             // Saturday -> Monday
        default: offset = -(weekday - 2)
        }
        return cal.date(byAdding: .day, value: offset, to: start) ?? start
    }

    static func shift(_ monday: Date, byWeeks weeks: Int, timeZone: TimeZone = .current) -> Date {
        calendar(timeZone).date(byAdding: .day, value: weeks * 7, to: monday) ?? monday
    }

    /// Monday through Friday starting at `monday`.
    static func days(startingMonday monday: Date, items: [PlannerItem], today: String,
                     timeZone: TimeZone = .current,
                     resolve: (Date) -> WeekDayInfo) -> [PlannerWeekDay] {
        let cal = calendar(timeZone)
        return (0..<5).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday) ?? monday
            let day = PlannerItem.dayString(from: date, timeZone: timeZone)
            let forDay = items.filter { $0.dueDate == day }
            return PlannerWeekDay(day: day, info: resolve(date), items: PlannerListing.ordered(forDay, today: today))
        }
    }

    /// The week without the days that have already happened: a finished day is not a plan.
    ///
    /// A past day with something still undone is kept, showing only what is undone (its classes and its
    /// finished items are over), so overdue work does not drop out of sight the moment its day passes.
    /// Today and later are untouched.
    static func hidingPast(_ days: [PlannerWeekDay], today: String) -> [PlannerWeekDay] {
        days.compactMap { day in
            guard day.day < today else { return day }
            // A test that has happened is gone, not overdue.
            let open = day.items.filter { !$0.completed && !($0.kind == .test && $0.parentId == nil) }
            guard !open.isEmpty else { return nil }
            var kept = day
            kept.info = WeekDayInfo(weekdayName: day.info.weekdayName, classes: [], emptyMessage: nil)
            kept.items = open
            return kept
        }
    }

    /// Whether the school week starting `monday` is over (its Friday is before `today`), so there is
    /// nothing in it worth going back to.
    static func isWhollyPast(monday: Date, today: String, timeZone: TimeZone = .current) -> Bool {
        let friday = calendar(timeZone).date(byAdding: .day, value: 4, to: monday) ?? monday
        return PlannerItem.dayString(from: friday, timeZone: timeZone) < today
    }

    /// "Mon, Oct 5 - Fri, Oct 9"-style range for the header, from the Monday.
    static func rangeLabel(monday: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let cal = calendar(timeZone)
        let friday = cal.date(byAdding: .day, value: 4, to: monday) ?? monday
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: monday)) – \(formatter.string(from: friday))"
    }

    /// "Tuesday, Oct 6", with " · Today" added for today.
    static func dayTitle(forDay day: String, today: String, timeZone: TimeZone = .current,
                         locale: Locale = .current) -> String {
        guard let date = PlannerItem.date(fromDay: day, timeZone: timeZone) else { return day }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        let title = formatter.string(from: date)
        return day == today ? "\(title) · Today" : title
    }
}

// MARK: - The Schedule tab (a day's blocks, with tests and homework inside their class's row)

enum PlannerSchedule {

    /// For each block of the day, in order, the student's tests and homework for its class
    /// (`PlannerWeekDay.badgedItems`, so the rule is the one the week and Tomorrow views use). The row
    /// shows them as tags inside itself.
    ///
    /// `hasClass` says whether the student has a class in that letter that actually meets this day. A
    /// block that is not theirs, is Free, or does not meet gets none, so its items stay in the Planned
    /// list instead of vanishing. A letter that appears twice in a day takes its items on the first row
    /// only, so nothing is shown twice.
    static func attachments(blockLetters: [String], hasClass: (String) -> Bool, isFree: (String) -> Bool = { _ in false },
                            items: [PlannerItem], day: String) -> [[PlannerItem]] {
        var seen = Set<String>()
        return blockLetters.map { letter in
            let block = letter.uppercased()
            let free = isFree(block)
            guard block != "N/A", free || hasClass(block), seen.insert(block).inserted else { return [] }
            return PlannerWeekDay.badgedItems(block: block, day: day, in: items, isFree: free)
        }
    }

    /// `items` without the ones in `attachments`: what is left goes in the Planned list, so an item is in
    /// its class's row or in the list, never both.
    static func unattached(_ items: [PlannerItem], attachments: [[PlannerItem]]) -> [PlannerItem] {
        let placed = Set(attachments.flatMap { $0.map { $0.id } })
        return items.filter { !placed.contains($0.id) }
    }
}

// MARK: - A class row on Tomorrow: each homework on its own line, tests as blocks

/// What Tomorrow's class row draws for the planner items badged on it (`PlannerWeekDay.badgedItems`).
struct TomorrowClassItems: Equatable {
    /// Homework: each is its own line with its own checkbox, under the class name.
    var homework: [PlannerItem]
    /// Everything else (tests): blocks along the bottom, with the + after them.
    var tests: [PlannerItem]

    /// `badged` split for one class row. A row that already holds an old-style typed note keeps that note on
    /// its line and checkbox, so planner homework stays a block there rather than a line of its own.
    static func split(_ badged: [PlannerItem], legacyNote: String) -> TomorrowClassItems {
        guard legacyNote.isEmpty else { return TomorrowClassItems(homework: [], tests: badged) }
        return TomorrowClassItems(homework: badged.filter { $0.kind == .homework },
                                  tests: badged.filter { $0.kind != .homework })
    }

    static let plainHeight: CGFloat = 100
    static let testsOnlyHeight: CGFloat = 132

    // The lines inside a class card all share one size and one gap, so nothing can overlap or drift.
    static let lineHeight: CGFloat = 30
    static let lineGap: CGFloat = 6
    static let headerHeight: CGFloat = 44
    static let bottomPad: CGFloat = 14

    /// The row's height. With homework lines the card is a column of equal lines: one per homework, then
    /// the + (its own line, in the checkbox column), then one for the tests if there are any.
    var rowHeight: CGFloat {
        guard !homework.isEmpty else { return tests.isEmpty ? TomorrowClassItems.plainHeight : TomorrowClassItems.testsOnlyHeight }
        let lines = CGFloat(homework.count + 1 + (tests.isEmpty ? 0 : 1))
        return TomorrowClassItems.headerHeight + lines * TomorrowClassItems.lineHeight
            + (lines - 1) * TomorrowClassItems.lineGap + TomorrowClassItems.bottomPad
    }
}

// MARK: - Limits and what can be ticked

enum PlannerLimits {
    /// The most homework a class can have due on one day.
    static let maxHomeworkPerClassDay = 3

    /// Homework (not steps) for `block` due `day`, finished or not, other than the item `excluding`.
    static func homeworkCount(block: String, day: String, in items: [PlannerItem], excluding id: String? = nil) -> Int {
        items.filter {
            $0.kind == .homework && $0.parentId == nil && $0.dueDate == day && $0.id != id
                && $0.classBlock?.uppercased() == block.uppercased()
        }.count
    }

    static func homeworkIsFull(block: String, day: String, in items: [PlannerItem], excluding id: String? = nil) -> Bool {
        homeworkCount(block: block, day: day, in: items, excluding: id) >= maxHomeworkPerClassDay
    }

    static let fullMessage = "A class can have 3 homework due on one day. Finish or delete one first."

    /// Whether saving `item` could take a class over the limit and needs checking: new homework for a class,
    /// or homework moved to another class or day. An unchanged edit never does.
    static func needsHomeworkCheck(_ item: PlannerItem, replacing existing: PlannerItem?) -> Bool {
        guard item.kind == .homework, item.parentId == nil, item.classBlock != nil else { return false }
        guard let existing = existing else { return true }
        return existing.kind != .homework || existing.classBlock != item.classBlock || existing.dueDate != item.dueDate
    }

    /// A test is not ticked off: it happens, and then it is gone. A step of a test is homework-like work and
    /// can be.
    static func canTick(_ item: PlannerItem) -> Bool {
        !(item.kind == .test && item.parentId == nil)
    }

    /// `items` without the tests that have happened (due before `today`) and the steps of those tests.
    static func hidingPastTests(_ items: [PlannerItem], today: String) -> [PlannerItem] {
        let past = Set(items.filter { $0.kind == .test && $0.parentId == nil && $0.dueDate < today }.map { $0.id })
        return items.filter { !past.contains($0.id) && !($0.parentId.map { past.contains($0) } ?? false) }
    }

    /// Splits the Tasks list into what is coming and what is Past. Past is an item that was due before `today`
    /// and is not done, with its steps. Everything else stays in Upcoming; a finished item due today or later
    /// sits at the end, faded, so a stray tick can be undone. Gone from both: tests that have happened
    /// (`hidingPastTests`) and anything finished whose day has passed.
    static func splitPast(_ items: [PlannerItem], today: String) -> (upcoming: [PlannerItem], past: [PlannerItem]) {
        let visible = hidingPastTests(items, today: today).filter { !($0.completed && $0.dueDate < today) }
        let pastIDs = Set(visible.filter { $0.parentId == nil && !$0.completed && $0.dueDate < today }.map { $0.id })
        let isPast: (PlannerItem) -> Bool = { pastIDs.contains($0.id) || ($0.parentId.map { pastIDs.contains($0) } ?? false) }
        return (visible.filter { !isPast($0) }, visible.filter(isPast))
    }
}

