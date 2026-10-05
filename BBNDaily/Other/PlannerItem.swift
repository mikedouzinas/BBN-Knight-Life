//
//  PlannerItem.swift
//  BBNDaily
//
//  HQ-2180. One thing a student has coming up: a test, a piece of homework, a game, an
//  appointment. Stored at users/{uid}/planner/{itemId} - a subcollection, not a field on the user
//  document, because the user document is readable by any signed-in student and an
//  appointment must not be. See the rule in firebase/firestore.rules.
//
//  This file is the pure part: the shape, how it reads from and writes to a Firestore dictionary,
//  and the checks a write must pass. No Firebase calls, so it is unit tested without a network
//  (PlannerItemTests). PlannerStore does the talking to Firestore.
//
//  Everything here mirrors validPlannerItem in firestore.rules. The server is the enforcement;
//  this is so a student gets a sentence instead of a refused write.
//

import Foundation
import FirebaseFirestore

/// The four kinds the app knows how to draw. The raw values are what is stored.
enum PlannerKind: String, CaseIterable {
    case test
    case homework
    case sports
    case appointment
}

/// When, if at all, to remind the student about an item (HQ-2185). The raw values are what is
/// stored, and the same strings the rules accept.
enum PlannerReminder: String, CaseIterable {
    case none
    /// The evening before it is due.
    case evening
    /// The morning it is due.
    case morning
    /// An exact moment the student picked, stored in `remindAt`.
    case custom
}

struct PlannerItem: Equatable {
    var id: String
    var kind: PlannerKind
    var title: String
    /// A day, "yyyy-MM-dd". A string rather than a Date so "the 20th" is the 20th for the student
    /// who typed it whatever timezone a phone later wakes up in, and so a range of days is a plain
    /// string range query (ISO order is chronological order). Same form schedules use since HQ-603.
    var dueDate: String
    /// Optional "HH:mm", 24-hour.
    var dueTime: String?
    /// Optional A-G: the class this belongs to.
    var classBlock: String?
    var notes: String?
    var completed: Bool
    var createdAt: Date
    /// The item this is a step of (mini deadlines, HQ-2187). Nil for a top-level item.
    var parentId: String?
    /// A big deadline (HQ-2186).
    var isBig: Bool
    /// Whether and when to remind the student (HQ-2185). `.none` when absent, so every item written
    /// before this field existed simply has no reminder.
    var reminder: PlannerReminder
    /// The moment for `.custom`; ignored otherwise.
    var remindAt: Date?

    init(id: String, kind: PlannerKind, title: String, dueDate: String, dueTime: String? = nil,
         classBlock: String? = nil, notes: String? = nil, completed: Bool = false,
         createdAt: Date = Date(), parentId: String? = nil, isBig: Bool = false,
         reminder: PlannerReminder = .none, remindAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.classBlock = classBlock
        self.notes = notes
        self.completed = completed
        self.createdAt = createdAt
        self.parentId = parentId
        self.isBig = isBig
        self.reminder = reminder
        self.remindAt = remindAt
    }
}

// MARK: - Days

extension PlannerItem {
    /// One formatter, with a fixed locale. A DateFormatter left on the device locale can emit
    /// non-ASCII digits (Arabic, Thai, ...) or a different calendar, which writes a due date the
    /// rules reject and no query ever finds. HQ-607 was a launch crash from exactly that family.
    /// isLenient is off so "2026-02-30" is refused rather than quietly becoming March 2nd.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    /// The stored form of a day, in the phone's own timezone.
    static func dayString(from date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = dayFormatter
        let original = formatter.timeZone
        formatter.timeZone = timeZone
        defer { formatter.timeZone = original }
        return formatter.string(from: date)
    }

    /// The day as a Date at midnight in `timeZone`, or nil if `day` is not a real calendar day.
    static func date(fromDay day: String, timeZone: TimeZone = .current) -> Date? {
        guard day.count == 10 else { return nil }
        let formatter = dayFormatter
        let original = formatter.timeZone
        formatter.timeZone = timeZone
        defer { formatter.timeZone = original }
        guard let date = formatter.date(from: day) else { return nil }
        // Round-trip: a non-lenient formatter still accepts a few shapes it should not, so insist
        // the string we get back is the string we were given.
        return formatter.string(from: date) == day ? date : nil
    }

    /// Whether `time` is a real "HH:mm" 24-hour time.
    static func isValidTime(_ time: String) -> Bool {
        let parts = time.split(separator: ":", omittingEmptySubsequences: false)
        guard time.count == 5, parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              parts[0].count == 2, parts[1].count == 2 else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }
}

// MARK: - Validation

/// Why an item cannot be saved, worded for the student. Mirrors validPlannerItem in the rules.
enum PlannerValidationError: Error, Equatable {
    case emptyTitle
    case titleTooLong(limit: Int)
    case badDate
    case badTime
    case badClassBlock
    case notesTooLong(limit: Int)
    case badParent
    case missingID
    case missingReminderTime

    var message: String {
        switch self {
        case .emptyTitle: return "Give it a title."
        case .titleTooLong(let limit): return "Titles can be up to \(limit) characters."
        case .badDate: return "That isn't a real date."
        case .badTime: return "That isn't a real time."
        case .badClassBlock: return "Pick a block from A to G."
        case .notesTooLong(let limit): return "Notes can be up to \(limit) characters."
        case .badParent: return "A step can't belong to itself."
        case .missingID: return "That item couldn't be found."
        case .missingReminderTime: return "Pick a time for the reminder."
        }
    }
}

extension PlannerItem {
    static let parentIdLimit = 40
    private static let blocks = Set(["A", "B", "C", "D", "E", "F", "G"])

    /// The first reason this item cannot be saved, or nil if it can. Checked before a write so the
    /// student is told what is wrong; the rules are still the enforcement.
    func validationError() -> PlannerValidationError? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { return .emptyTitle }
        if title.count > FieldLimits.plannerTitle { return .titleTooLong(limit: FieldLimits.plannerTitle) }
        if PlannerItem.date(fromDay: dueDate) == nil { return .badDate }
        if let dueTime = dueTime, !PlannerItem.isValidTime(dueTime) { return .badTime }
        if let classBlock = classBlock, !PlannerItem.blocks.contains(classBlock) { return .badClassBlock }
        if let notes = notes, notes.count > FieldLimits.plannerNotes { return .notesTooLong(limit: FieldLimits.plannerNotes) }
        if let parentId = parentId {
            if parentId.isEmpty || parentId.count > PlannerItem.parentIdLimit || parentId == id { return .badParent }
        }
        if reminder == .custom && remindAt == nil { return .missingReminderTime }
        return nil
    }
}

// MARK: - Firestore shape

extension PlannerItem {
    /// Reads one stored document. Returns nil for anything that is not a usable item, and in
    /// particular for a `kind` this build does not know: a newer app may add a fifth kind, and an
    /// older one must skip that item rather than crash or draw it as something it is not.
    init?(id: String, data: [String: Any]) {
        guard let rawKind = data["kind"] as? String, let kind = PlannerKind(rawValue: rawKind),
              let title = data["title"] as? String, !title.isEmpty,
              let dueDate = data["dueDate"] as? String, PlannerItem.date(fromDay: dueDate) != nil
        else { return nil }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            // A write still in flight reads back with no server timestamp yet; do not drop it.
            createdAt = Date()
        }

        self.init(
            id: id,
            kind: kind,
            title: title,
            dueDate: dueDate,
            dueTime: data["dueTime"] as? String,
            classBlock: data["classBlock"] as? String,
            notes: data["notes"] as? String,
            completed: (data["completed"] as? Bool) ?? false,
            createdAt: createdAt,
            parentId: data["parentId"] as? String,
            isBig: (data["isBig"] as? Bool) ?? false,
            // An unknown reminder (a newer build's) reads as none rather than dropping the item.
            reminder: (data["reminder"] as? String).flatMap { PlannerReminder(rawValue: $0) } ?? .none,
            remindAt: (data["remindAt"] as? Timestamp)?.dateValue()
        )
    }

    /// What is written. Optional fields are left out rather than written empty, because the rules
    /// validate an optional field only when it is present and an empty string would fail them.
    /// isBig is written only when true, to keep the common document small.
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "kind": kind.rawValue,
            "title": title,
            "dueDate": dueDate,
            "completed": completed,
            "createdAt": Timestamp(date: createdAt),
        ]
        if let dueTime = dueTime { data["dueTime"] = dueTime }
        if let classBlock = classBlock { data["classBlock"] = classBlock }
        if let notes = notes, !notes.isEmpty { data["notes"] = notes }
        if let parentId = parentId { data["parentId"] = parentId }
        if isBig { data["isBig"] = true }
        // Written only when set, like every other optional: an item with no reminder is the same
        // document it was before this field existed.
        if reminder != .none { data["reminder"] = reminder.rawValue }
        if reminder == .custom, let remindAt = remindAt { data["remindAt"] = Timestamp(date: remindAt) }
        return data
    }
}
