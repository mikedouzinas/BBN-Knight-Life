//
//  PlannerReminders.swift
//  BBNDaily
//
//  HQ-2185. Reminders for a student's planner items, as local notifications.
//
//  LOCAL, not the push in HQ-112. That push is for school-wide schedule changes, where the server
//  knows something every student needs to hear. A student's private list of tests and
//  appointments should not leave their phone just to be notified about, and the planner's rules
//  (owner-only) exist to keep it that way.
//
//  THE CAP. iOS keeps at most 64 pending local notifications per app. setNotifications() already
//  spends that on class reminders (HQ-639). Planner reminders share the same 64, and the split is
//  decided here so neither can quietly starve the other:
//
//    - Planner reminders are chosen FIRST, soonest first, at most `maxPending` (20) of them.
//    - Class reminders get what is left: 64 minus however many planner reminders there actually are.
//
//  So a busy fortnight of classes cannot eat the reminder for a test (the planner slice is taken
//  before classes are counted), and a long list of items cannot remove class reminders beyond 20
//  (the cap), so classes always keep at least 44. Slots the planner does not use go back to
//  classes. A reminder beyond the 20th is not lost, only not scheduled yet: setNotifications()
//  runs on every launch and after every change, so it is scheduled once earlier ones have fired.
//
//  Everything here is pure (no UserNotifications, no Firestore) so it is unit tested; the
//  scheduling calls live in PlannerReminderScheduler.
//

import Foundation

/// One local notification to schedule.
struct ReminderRequest: Equatable {
    /// Deterministic ("planner:<item>:<rung>"), so scheduling the same reminder again replaces it
    /// instead of stacking a second, and so planner requests can be told from class requests.
    var identifier: String
    var fireDate: Date
    var title: String
    var body: String
    var itemID: String
}

enum PlannerReminders {

    /// iOS's limit on pending local notifications for one app.
    static let systemLimit = 64
    /// The most planner reminders scheduled at once (see the note at the top).
    static let maxPending = 20
    static let identifierPrefix = "planner:"

    /// "Evening before" and "morning of" times, in the phone's own timezone. 7 PM is after
    /// practice and before most students' evening is spoken for; 7 AM is before the 7:55 CAB and
    /// the 8:15 first block.
    static let eveningHour = 19
    static let morningHour = 7

    // MARK: - Budget

    /// How many class reminders may be scheduled once `plannerCount` planner reminders are.
    static func classBudget(plannerCount: Int) -> Int {
        systemLimit - min(max(plannerCount, 0), maxPending)
    }

    // MARK: - When

    /// When an item's reminder fires, or nil if it has none or the moment has already passed.
    static func fireDate(for item: PlannerItem, now: Date, timeZone: TimeZone = .current) -> Date? {
        let raw: Date?
        switch item.reminder {
        case .none:
            raw = nil
        case .custom:
            raw = item.remindAt
        case .evening, .morning:
            guard let due = PlannerItem.date(fromDay: item.dueDate, timeZone: timeZone) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            // setting the hour on the calendar day, not adding 24 hours: the evening before a
            // daylight-saving change is 23 or 25 hours earlier than the due date's midnight.
            let day = item.reminder == .evening ? calendar.date(byAdding: .day, value: -1, to: due) : due
            raw = day.flatMap {
                calendar.date(bySettingHour: item.reminder == .evening ? eveningHour : morningHour,
                              minute: 0, second: 0, of: $0)
            }
        }
        // Not "now or later": a reminder due this very second would fire before the student has
        // looked up, and an iOS trigger already in the past never fires at all.
        guard let date = raw, date > now.addingTimeInterval(30) else { return nil }
        return date
    }

    // MARK: - What

    static func identifier(itemID: String, rung: Int = 0) -> String { "\(identifierPrefix)\(itemID):\(rung)" }

    static func isPlannerIdentifier(_ identifier: String) -> Bool { identifier.hasPrefix(identifierPrefix) }

    /// The reminders to schedule, soonest first, at most `maxPending`.
    ///
    /// Left out: a finished item, an item with no reminder or whose moment has passed, and a
    /// school key date (read-only, shown to everyone, never the student's to be reminded about
    /// through their own planner).
    static func plan(items: [PlannerItem], now: Date, timeZone: TimeZone = .current) -> [ReminderRequest] {
        let requests: [ReminderRequest] = items.flatMap { item -> [ReminderRequest] in
            guard !item.completed, !item.isSchoolKeyDate else { return [] }
            // A big deadline's countdown REPLACES its single reminder rather than adding to it: a
            // test with a "night before" reminder AND a "night before" rung would notify twice.
            if item.isBig { return ladderRequests(for: item, now: now, timeZone: timeZone) }
            guard let fire = fireDate(for: item, now: now, timeZone: timeZone) else { return [] }
            return [ReminderRequest(identifier: identifier(itemID: item.id), fireDate: fire,
                                    title: item.title, body: body(for: item, fireDate: fire, timeZone: timeZone),
                                    itemID: item.id)]
        }
        let ordered = requests.sorted {
            $0.fireDate != $1.fireDate ? $0.fireDate < $1.fireDate : $0.identifier < $1.identifier
        }
        return Array(ordered.prefix(maxPending))
    }

    /// What the notification says under the title: the kind, and when it is due, in words that are
    /// still right if the notification is read hours after it fired.
    static func body(for item: PlannerItem, fireDate: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let fireDay = PlannerItem.dayString(from: fireDate, timeZone: timeZone)
        let when: String
        if item.dueDate == fireDay {
            when = "due today"
        } else if let due = PlannerItem.date(fromDay: item.dueDate, timeZone: timeZone),
                  let next = calendar.date(byAdding: .day, value: 1, to: fireDate),
                  PlannerItem.dayString(from: next, timeZone: timeZone) == PlannerItem.dayString(from: due, timeZone: timeZone) {
            when = "due tomorrow"
        } else {
            when = "due \(PlannerListing.dayLabel(forDay: item.dueDate, now: fireDate, timeZone: timeZone))"
        }
        var parts = [item.kind.label, when]
        if let block = item.classBlock { parts.append("Block \(block)") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - The countdown for a big deadline (HQ-2186)

extension PlannerReminders {

    /// When one rung of an item's countdown fires, or nil if it has already passed.
    ///
    /// Skipped, never fired late. A test added two days out has no "a week before" and no "3 days
    /// before" to give: firing those at once would be a notification about a deadline that is, by
    /// now, closer than the reminder says, and an iOS trigger already in the past never fires at
    /// all. So it simply gets the rungs that are still ahead.
    ///
    /// Before the due day a rung is 7 PM, like the plain "night before" reminder; the morning of is
    /// 7 AM. The day is stepped on the calendar and then the hour set, so a rung is still 7 PM
    /// across a daylight-saving change.
    static func fireDate(rung: LadderRung, for item: PlannerItem, now: Date, timeZone: TimeZone = .current) -> Date? {
        guard let due = PlannerItem.date(fromDay: item.dueDate, timeZone: timeZone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = calendar.date(byAdding: .day, value: -rung.daysBefore, to: due),
              let moment = calendar.date(bySettingHour: rung == .morningOf ? morningHour : eveningHour,
                                         minute: 0, second: 0, of: day),
              moment > now.addingTimeInterval(30) else { return nil }
        return moment
    }

    /// The reminders for a big deadline: one per rung that is on and still ahead.
    static func ladderRequests(for item: PlannerItem, now: Date, timeZone: TimeZone = .current) -> [ReminderRequest] {
        LadderRung.allCases.compactMap { rung in
            guard item.rungs.contains(rung),
                  let fire = fireDate(rung: rung, for: item, now: now, timeZone: timeZone) else { return nil }
            return ReminderRequest(identifier: identifier(itemID: item.id, rung: rung.position), fireDate: fire,
                                   title: ladderTitle(item.title, rung: rung), body: ladderBody(for: item),
                                   itemID: item.id)
        }
    }

    /// Says what and when: "Chemistry test in 3 days", not "Reminder".
    static func ladderTitle(_ title: String, rung: LadderRung) -> String {
        switch rung {
        case .week: return "\(title) in 1 week"
        case .threeDays: return "\(title) in 3 days"
        case .dayBefore: return "\(title) tomorrow"
        case .morningOf: return "\(title) today"
        }
    }

    private static func ladderBody(for item: PlannerItem) -> String {
        var parts = [item.kind.label]
        if let block = item.classBlock { parts.append("Block \(block)") }
        return parts.joined(separator: " · ")
    }

    /// Whether any rung of this item's countdown is both on and still ahead.
    static func hasUpcomingRung(_ item: PlannerItem, now: Date, timeZone: TimeZone = .current) -> Bool {
        !ladderRequests(for: item, now: now, timeZone: timeZone).isEmpty
    }
}

// MARK: - The class-reminder budget, extracted

enum NotificationBudget {
    /// For each school day in order, whether its class reminders are scheduled. This is the loop
    /// that was inside setNotifications() (HQ-639), unchanged in behavior and now testable: walk
    /// forward, and stop scheduling at the first day that would overflow, for good.
    ///
    /// The latch matters. Without it a later, lighter day could slip under the cap after a heavier
    /// one was skipped, leaving a day missing from the middle: a student reminded for Monday and
    /// Wednesday and silently not Tuesday reads as "nothing Tuesday", not as "the count ran out".
    ///
    /// - Parameter dayBlockCounts: reminders each day wants, or 0 for a day that gets none
    ///   (no school, notifications off). A day with 0 never trips the latch.
    static func fit(dayBlockCounts: [Int], budget: Int) -> [Bool] {
        var scheduled = 0
        var full = false
        return dayBlockCounts.map { count in
            guard count > 0, !full else { return false }
            guard scheduled + count <= budget else {
                full = true
                return false
            }
            scheduled += count
            return true
        }
    }
}

// MARK: - What the app knows about, kept between launches

/// The planner items the reminders are built from.
///
/// A cache, and a persisted one. setNotifications() clears every pending notification and rebuilds
/// them, and it runs at launch, before any planner read has finished. With no memory of the planner
/// it would rebuild the class reminders and drop every planner one, and a student offline when they
/// open the app would lose the reminder for a test without ever seeing it go. So the open,
/// reminder-bearing items are saved on the phone and read back at launch.
///
/// It holds only what a reminder needs, on the device that was going to show those same words in a
/// notification anyway, and it is cleared on sign-out.
struct PlannerReminderCache {
    private(set) var itemsByID: [String: PlannerItem]

    /// The fields a reminder is built from. Change detection compares these and nothing else: an
    /// edit to an item's notes, or the createdAt a restored-from-disk item never had, changes no
    /// reminder, so it must not cost a reschedule.
    private struct Signature: Equatable {
        var title: String, kind: PlannerKind, dueDate: String, classBlock: String?
        var completed: Bool, reminder: PlannerReminder, remindAt: Date?
        var isBig: Bool, rungs: Set<LadderRung>
        init(_ item: PlannerItem) {
            title = item.title; kind = item.kind; dueDate = item.dueDate; classBlock = item.classBlock
            completed = item.completed; reminder = item.reminder; remindAt = item.remindAt
            isBig = item.isBig; rungs = item.rungs
        }
    }
    private static func signatures(_ items: [String: PlannerItem]) -> [String: Signature] { items.mapValues(Signature.init) }

    init(items: [PlannerItem] = []) {
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    var items: [PlannerItem] { Array(itemsByID.values) }

    /// Applies a read that covered `window` (inclusive "yyyy-MM-dd" days): items inside it are
    /// replaced by what came back, so one deleted elsewhere drops out, and items outside it are
    /// kept, because a read of one month says nothing about another. Returns whether anything
    /// changed, so callers only reschedule when they need to.
    @discardableResult
    mutating func apply(items fetched: [PlannerItem], window: (start: String, end: String)) -> Bool {
        var next = itemsByID.filter { !($0.value.dueDate >= window.start && $0.value.dueDate <= window.end) }
        for item in fetched where item.dueDate >= window.start && item.dueDate <= window.end {
            next[item.id] = item
        }
        let changed = PlannerReminderCache.signatures(next) != PlannerReminderCache.signatures(itemsByID)
        itemsByID = next   // always keep the fresh copy, even when no reminder is affected
        return changed
    }

    /// A save or delete the student just made, applied straight away rather than waiting for a read.
    @discardableResult
    mutating func upsert(_ item: PlannerItem) -> Bool {
        let changed = itemsByID[item.id].map(Signature.init) != Signature(item)
        itemsByID[item.id] = item
        return changed
    }

    @discardableResult
    mutating func remove(id: String) -> Bool { itemsByID.removeValue(forKey: id) != nil }

    // MARK: Persistence

    /// Only items a reminder could still come from: not finished, and carrying a reminder or a
    /// countdown. `isBig` and `rungs` are optional so a cache saved by the previous build still reads.
    private struct Stored: Codable {
        var id: String, kind: String, title: String, dueDate: String
        var classBlock: String?, reminder: String, remindAt: Date?
        var isBig: Bool?, rungs: [String]?
    }

    func encoded() -> Data? {
        let keep = itemsByID.values
            .filter { !$0.completed && ($0.reminder != .none || $0.isBig) }
            .sorted { $0.id < $1.id }
        let stored: [Stored] = keep.map { item in
            // In ladder order, so the saved copy doesn't reorder between writes.
            let rungNames = LadderRung.allCases.filter { item.rungs.contains($0) }.map { $0.rawValue }
            return Stored(id: item.id, kind: item.kind.rawValue, title: item.title, dueDate: item.dueDate,
                          classBlock: item.classBlock, reminder: item.reminder.rawValue, remindAt: item.remindAt,
                          isBig: item.isBig ? true : nil, rungs: item.isBig ? rungNames : nil)
        }
        return try? JSONEncoder().encode(stored)
    }

    init(decoding data: Data?) {
        guard let data = data, let stored = try? JSONDecoder().decode([Stored].self, from: data) else {
            self.init(items: [])
            return
        }
        self.init(items: stored.compactMap { entry -> PlannerItem? in
            guard let kind = PlannerKind(rawValue: entry.kind), let reminder = PlannerReminder(rawValue: entry.reminder) else { return nil }
            let rungs = entry.rungs.map { names in Set(names.compactMap { LadderRung(rawValue: $0) }) } ?? Set(LadderRung.allCases)
            return PlannerItem(id: entry.id, kind: kind, title: entry.title, dueDate: entry.dueDate, classBlock: entry.classBlock,
                               isBig: entry.isBig ?? false, reminder: reminder, remindAt: entry.remindAt, rungs: rungs)
        })
    }
}

// MARK: - Telling the student why a reminder won't show up

enum ReminderPermission: Equatable {
    case granted
    case denied
    /// Not asked yet, or not known yet.
    case unknown
}

extension PlannerReminders {
    /// What to say under the reminder control, or nil when everything is fine. Said out loud
    /// because the alternative is a student choosing a reminder, seeing nothing wrong, and never
    /// getting it: exactly the failure nobody notices until the test they missed.
    ///
    /// Checked in the order a student could fix them: a moment that has passed is about what they
    /// just picked; the others are about the phone.
    static func note(for item: PlannerItem, now: Date, permission: ReminderPermission, appNotificationsOn: Bool,
                     timeZone: TimeZone = .current) -> String? {
        if item.isBig {
            // Nothing switched on is a choice, not a problem. Rungs switched on but all already gone
            // is the case worth saying out loud.
            guard !item.rungs.isEmpty else { return nil }
            if !hasUpcomingRung(item, now: now, timeZone: timeZone) {
                return "Those times have already passed, so there won't be a reminder."
            }
            if permission == .denied {
                return "Notifications are off for Knight Life in your iPhone's Settings, so these reminders won't show up."
            }
            if !appNotificationsOn {
                return "Notifications are turned off in Knight Life's settings, so these reminders won't show up."
            }
            return nil
        }
        guard item.reminder != .none else { return nil }
        if fireDate(for: item, now: now, timeZone: timeZone) == nil {
            return item.reminder == .custom
                ? "That time has already passed, so there won't be a reminder."
                : "That moment has already passed, so there won't be a reminder."
        }
        if permission == .denied {
            return "Notifications are off for Knight Life in your iPhone's Settings, so this reminder won't show up."
        }
        if !appNotificationsOn {
            return "Notifications are turned off in Knight Life's settings, so this reminder won't show up."
        }
        return nil
    }

    /// The time a custom reminder starts at when first chosen: the evening before, since that is
    /// what the other choices do, or an hour from now if that has already passed.
    static func defaultCustomTime(forDueDay day: String, now: Date, timeZone: TimeZone = .current) -> Date {
        let evening = PlannerItem(id: "x", kind: .test, title: "x", dueDate: day, reminder: .evening)
        return fireDate(for: evening, now: now, timeZone: timeZone) ?? now.addingTimeInterval(3600)
    }
}
