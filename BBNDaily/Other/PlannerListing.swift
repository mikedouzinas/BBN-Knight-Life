//
//  PlannerListing.swift
//  BBNDaily
//
//  HQ-2181. The decisions behind the Tasks tab's "Upcoming" list and its add/edit sheet, kept
//  free of UIKit and Firebase so they can be unit tested: what order items appear in, which are
//  overdue, how a day is worded, and how the sheet's fields become a PlannerItem.
//

import Foundation

enum PlannerListing {

    /// Not done, and due before today. A completed item is never overdue, whatever its date.
    static func isOverdue(_ item: PlannerItem, today: String) -> Bool {
        !item.completed && item.dueDate < today
    }

    /// The order the list shows:
    ///   1. overdue, oldest first (the one that has been waiting longest is the one to see)
    ///   2. coming up, soonest first
    ///   3. completed, most recent first, last: still there to reopen, out of the way
    /// Ties fall back to creation time and then title, so two items due the same day do not swap
    /// places every time the list reloads.
    ///
    /// Dates compare as strings on purpose: "yyyy-MM-dd" sorts chronologically.
    static func ordered(_ items: [PlannerItem], today: String) -> [PlannerItem] {
        func bucket(_ item: PlannerItem) -> Int {
            if item.completed { return 2 }
            return isOverdue(item, today: today) ? 0 : 1
        }
        return items.sorted { a, b in
            let ba = bucket(a), bb = bucket(b)
            if ba != bb { return ba < bb }
            if a.dueDate != b.dueDate {
                // Completed items run newest first; everything else, oldest/soonest first.
                return ba == 2 ? a.dueDate > b.dueDate : a.dueDate < b.dueDate
            }
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.title < b.title
        }
    }

    /// "Today", "Tomorrow", "Yesterday", or a short weekday and date ("Tue, Oct 20").
    /// The relative words are decided on the stored day strings, so they are right in the phone's
    /// own timezone and testable with a fixed `now` and zone.
    static func dayLabel(forDay day: String, now: Date = Date(), timeZone: TimeZone = .current,
                         locale: Locale = .current) -> String {
        let calendar = Calendar(identifier: .gregorian)
        var zoned = calendar
        zoned.timeZone = timeZone
        func shifted(_ days: Int) -> String {
            let date = zoned.date(byAdding: .day, value: days, to: now) ?? now
            return PlannerItem.dayString(from: date, timeZone: timeZone)
        }
        if day == shifted(0) { return "Today" }
        if day == shifted(1) { return "Tomorrow" }
        if day == shifted(-1) { return "Yesterday" }
        guard let date = PlannerItem.date(fromDay: day, timeZone: timeZone) else { return day }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }

    /// The window the list loads, as stored day strings: a month back (so overdue items are
    /// still there to deal with) to six months ahead.
    static func loadWindow(now: Date = Date(), timeZone: TimeZone = .current) -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 180, to: now) ?? now
        return (PlannerItem.dayString(from: start, timeZone: timeZone),
                PlannerItem.dayString(from: end, timeZone: timeZone))
    }
}

/// What the add/edit sheet holds, before it becomes an item.
struct PlannerDraft: Equatable {
    var kind: PlannerKind = .homework
    var title: String = ""
    var dueDate: Date
    var classBlock: String?
    var notes: String = ""
    /// A new item starts with the evening-before reminder, the default HQ-2185 asked for; the student
    /// can switch it to none, morning-of, or a time of their own.
    var reminder: PlannerReminder = .evening
    var remindAt: Date?
    /// A big deadline carries a countdown (HQ-2186). Off for ordinary homework; a test turns it on
    /// by default (the editor does that when the kind becomes Test) so the one thing most worth
    /// being reminded about gets the most, without burying a worksheet in notifications.
    var isBig = false
    var rungs = Set(LadderRung.allCases)
    /// Set on a step the student is adding to a deadline (HQ-2187). An edit keeps the saved item's own
    /// `parentId`; this is for the one that does not exist yet.
    var parentId: String?

    /// A step of `parent`, to be typed in: the parent's kind and class (so it is drawn and filed with
    /// it), never a big deadline (the countdown is the parent's), the ordinary evening reminder.
    static func newStep(of parent: PlannerItem, today: String, timeZone: TimeZone = .current) -> PlannerDraft {
        let day = PlannerSteps.defaultStepDay(parentDue: parent.dueDate, today: today, timeZone: timeZone)
        var draft = PlannerDraft(dueDate: PlannerItem.date(fromDay: day, timeZone: timeZone) ?? Date())
        draft.kind = parent.kind
        draft.classBlock = parent.classBlock
        draft.parentId = parent.id
        return draft
    }

    /// A new item's starting point: homework due tomorrow, the most common thing to add.
    static func new(now: Date = Date(), timeZone: TimeZone = .current) -> PlannerDraft {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return PlannerDraft(dueDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
    }

    /// The sheet pre-filled from an item being edited.
    init(editing item: PlannerItem, timeZone: TimeZone = .current) {
        kind = item.kind
        title = item.title
        dueDate = PlannerItem.date(fromDay: item.dueDate, timeZone: timeZone) ?? Date()
        classBlock = item.classBlock
        notes = item.notes ?? ""
        reminder = item.reminder
        remindAt = item.remindAt
        isBig = item.isBig
        rungs = item.rungs
    }

    init(dueDate: Date) { self.dueDate = dueDate }

    /// The item to save. Editing keeps everything the sheet does not show: whether it is done,
    /// when it was created, which item it is a step of, whether it is a big deadline, and its time.
    /// Rebuilding from the sheet alone would quietly un-complete an item and orphan a step every
    /// time someone fixed a typo in its title.
    func makeItem(id: String, replacing existing: PlannerItem? = nil, now: Date = Date(),
                  timeZone: TimeZone = .current) -> PlannerItem {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlannerItem(
            id: id,
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: PlannerItem.dayString(from: dueDate, timeZone: timeZone),
            dueTime: existing?.dueTime,
            classBlock: classBlock,
            notes: cleanNotes.isEmpty ? nil : cleanNotes,
            completed: existing?.completed ?? false,
            createdAt: existing?.createdAt ?? now,
            parentId: existing?.parentId ?? parentId,
            isBig: isBig,
            reminder: reminder,
            // Only a custom reminder carries a time; a stale one from an earlier choice is dropped.
            remindAt: reminder == .custom ? remindAt : nil,
            rungs: rungs
        )
    }
}

// MARK: - Wording

extension PlannerKind {
    /// What the student reads. HQ-2182 gives each kind its color and symbol next to this.
    var label: String {
        switch self {
        case .test: return "Test"
        case .homework: return "Homework"
        case .sports: return "Sports"
        case .appointment: return "Appointment"
        }
    }
}

extension PlannerListing {
    /// The second line of a row: "Overdue · Yesterday · Test · Block C".
    static func subtitle(for item: PlannerItem, today: String, now: Date = Date(),
                         timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        var parts = [String]()
        if isOverdue(item, today: today) { parts.append("Overdue") }
        parts.append(dayLabel(forDay: item.dueDate, now: now, timeZone: timeZone, locale: locale))
        // A big deadline says so in words as well as with the mark on its row (HQ-2186).
        parts.append(item.isBig ? "Big \(item.kind.label.lowercased())" : item.kind.label)
        if let block = item.classBlock { parts.append("Block \(block)") }
        return parts.joined(separator: " · ")
    }
}
