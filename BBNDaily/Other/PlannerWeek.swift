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
    /// student can check against the list, not a score.
    var heavyCount: Int {
        items.filter { !$0.completed && ($0.kind == .test || $0.isBig) }.count
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
    static func showsOnClassRow(_ item: PlannerItem, classBlocks: Set<String>) -> Bool {
        guard let block = item.classBlock?.uppercased(), classBlocks.contains(block) else { return false }
        return item.kind == .test || item.kind == .homework
    }

    private var classBlocks: Set<String> { Set(info.classes.map { $0.block.uppercased() }) }

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
    static func badgedItems(block: String, day: String, in items: [PlannerItem]) -> [PlannerItem] {
        let upper = block.uppercased()
        let matching = items.filter { $0.dueDate == day && showsOnClassRow($0, classBlocks: [upper]) && $0.classBlock?.uppercased() == upper }
        return matching.filter { $0.kind == .test } + matching.filter { $0.kind == .homework }
    }

    /// The items to badge on the row for `block`: tests before homework, then in the order the day
    /// already has them. Finished ones are included, so ticking something off doesn't make it jump
    /// to a different place.
    func itemsOnClassRow(_ block: String) -> [PlannerItem] {
        // Only if that class is on this day's schedule: otherwise the item belongs in the list below.
        guard classBlocks.contains(block.uppercased()) else { return [] }
        return PlannerWeekDay.badgedItems(block: block, day: day, in: items)
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
        let badged = classBlocks
        rows += items.filter { !PlannerWeekDay.showsOnClassRow($0, classBlocks: badged) }.map { .item($0) }
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
