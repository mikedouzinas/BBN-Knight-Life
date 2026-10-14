//
//  PlannerSteps.swift
//  BBNDaily
//
//  HQ-2187. Mini deadlines: a big deadline split into smaller dated steps. A step is an ordinary
//  planner item whose `parentId` names the item it belongs to (the field HQ-2180 reserved), so it
//  shows on the calendar and week view on its own day, gets ordinary reminders (HQ-2185) and never
//  the big-deadline countdown (HQ-2186), and needs no storage of its own.
//
//  Everything here is pure, so the rules below are unit tested rather than hoped for:
//
//    - A step is never dated after its parent. Moving the parent earlier moves the steps that would
//      now be late, and says so; it must not leave an impossible plan.
//    - One level only: a step cannot have steps.
//    - Finishing every step does not finish the parent. Finishing the thing is the student's call.
//    - Deleting a parent deletes its steps, after a confirmation that says how many.
//
//  What is NOT enforced here: Firestore rules cannot cheaply compare a step to another document,
//  so "not after its parent" and "one level" are held by the app. The rules do refuse a step marked
//  big (a field on the step itself).
//

import Foundation

/// One suggested step, before it is saved.
struct StepSuggestion: Equatable {
    var title: String
    /// "yyyy-MM-dd"
    var dueDate: String
}

/// The parent and steps around one item, for the editor to enforce the rules above.
struct PlannerStepContext: Equatable {
    /// Set when the item is itself a step.
    var parent: PlannerItem?
    /// Set when the item is a parent: its steps, soonest first.
    var steps: [PlannerItem]

    static let none = PlannerStepContext(parent: nil, steps: [])
}

/// One row of the Upcoming list.
struct PlannerListRow: Equatable {
    var item: PlannerItem
    /// 0 for a normal item, 1 for a step shown under its parent.
    var depth: Int
    /// "2 of 4 steps done" on a parent that has steps.
    var progress: String?
}

enum PlannerSteps {

    /// The most steps one split offers. A paper has a handful of stages; past six the plan is longer
    /// than the thing being planned.
    static let maxSteps = 6

    // MARK: - Which items can have steps

    /// A top-level item the student owns. Not a step (one level only), and not a school key date
    /// (read-only, nothing behind it to attach children to).
    static func canHaveSteps(_ item: PlannerItem) -> Bool {
        item.parentId == nil && !item.isSchoolKeyDate
    }

    // MARK: - Suggesting dates

    /// Evenly spaced dates from tomorrow up to the due date, the last step landing on the due date.
    ///
    /// Offsets are whole calendar days, rounded to the nearest (half up) so the spacing is as even as
    /// whole days allow: ten days out with four steps is +3, +5, +8, +10. Never more steps than
    /// there are days (one a day at most), so a deadline three days out offered four steps gets
    /// three. Due today, or already past, has no room: empty.
    ///
    /// Days are stepped on the calendar and formatted, not computed by adding 86,400 seconds, so a
    /// daylight-saving change cannot put a step on the wrong date.
    static func suggest(parentTitle: String, dueDate: String, today: String, count: Int,
                        timeZone: TimeZone = .current) -> [StepSuggestion] {
        guard count > 0,
              let due = PlannerItem.date(fromDay: dueDate, timeZone: timeZone),
              let start = PlannerItem.date(fromDay: today, timeZone: timeZone) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let span = calendar.dateComponents([.day], from: start, to: due).day ?? 0
        guard span >= 1 else { return [] }
        let steps = min(count, maxSteps, span)
        return (1...steps).compactMap { index in
            let offset = (index * span + steps / 2) / steps
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return StepSuggestion(title: stepTitle(parentTitle: parentTitle, index: index, of: steps),
                                  dueDate: PlannerItem.dayString(from: date, timeZone: timeZone))
        }
    }

    /// "Chem paper: step 2 of 4". A long parent title is shortened so the whole thing still fits
    /// the one title limit the rules enforce (FieldLimits.plannerTitle) instead of being refused.
    static func stepTitle(parentTitle: String, index: Int, of total: Int) -> String {
        let suffix = ": step \(index) of \(total)"
        let room = max(FieldLimits.plannerTitle - suffix.count, 1)
        let clean = parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = clean.count > room ? String(clean.prefix(max(room - 1, 1))) + "…" : clean
        return head + suffix
    }

    /// The saved items for a split. A step is the parent's kind and class so it is drawn and filed
    /// with it, never big (the countdown is the parent's), and starts with the ordinary
    /// night-before reminder.
    static func makeSteps(for parent: PlannerItem, suggestions: [StepSuggestion], ids: [String],
                          now: Date = Date()) -> [PlannerItem] {
        zip(suggestions, ids).map { suggestion, id in
            PlannerItem(id: id, kind: parent.kind, title: suggestion.title, dueDate: suggestion.dueDate,
                        classBlock: parent.classBlock, completed: false, createdAt: now,
                        parentId: parent.id, isBig: false, reminder: .evening)
        }
    }

    // MARK: - A step never outlives its parent

    /// Why a step cannot be saved with this date, or nil if it can.
    static func dateProblem(step: PlannerItem, parent: PlannerItem?) -> String? {
        guard let parent = parent, step.parentId == parent.id, step.dueDate > parent.dueDate else { return nil }
        return "A step can't be due after the deadline it belongs to (\(PlannerListing.dayLabel(forDay: parent.dueDate)))."
    }

    /// The steps that would be late if the parent were due `newDueDate`, moved to that date. Empty when
    /// the parent moved later, or no step is past it. A finished step is moved too: the rule is about
    /// the plan, not about what is still open.
    static func reconcile(steps: [PlannerItem], toParentDue newDueDate: String) -> [PlannerItem] {
        steps.filter { $0.dueDate > newDueDate }.map { step in
            var moved = step
            moved.dueDate = newDueDate
            return moved
        }
    }

    // MARK: - Progress

    /// "2 of 4 steps done", or nil if the item has no steps.
    static func progress(of parent: PlannerItem, in items: [PlannerItem]) -> String? {
        let steps = items.filter { $0.parentId == parent.id }
        guard !steps.isEmpty else { return nil }
        let done = steps.filter { $0.completed }.count
        return "\(done) of \(steps.count) step\(steps.count == 1 ? "" : "s") done"
    }

    // MARK: - Context for the editor

    static func context(for item: PlannerItem, in items: [PlannerItem]) -> PlannerStepContext {
        if let parentId = item.parentId {
            return PlannerStepContext(parent: items.first { $0.id == parentId }, steps: [])
        }
        let steps = items.filter { $0.parentId == item.id }
            .sorted { $0.dueDate != $1.dueDate ? $0.dueDate < $1.dueDate : $0.createdAt < $1.createdAt }
        return PlannerStepContext(parent: nil, steps: steps)
    }

    // MARK: - Deleting a parent

    /// What the confirmation says. A parent with steps must name how many go with it.
    static func deleteMessage(parentTitle: String, stepCount: Int) -> String {
        guard stepCount > 0 else { return "Delete \"\(parentTitle)\"?" }
        return "Delete \"\(parentTitle)\" and its \(stepCount) step\(stepCount == 1 ? "" : "s")? This can't be undone."
    }

    // MARK: - The Upcoming list, with steps under their parent

    /// The list order, with each step directly under its parent and the parent carrying its progress.
    ///
    /// Parents and ordinary items keep the order PlannerListing gives them (overdue, soonest, done).
    /// Under a parent its steps run by their own date, whatever bucket they fall in: a step due next
    /// week sits under a parent due in a month. A step whose parent isn't in this list (outside the
    /// loaded window, or deleted elsewhere) is shown as an ordinary item rather than vanishing.
    static func rows(_ items: [PlannerItem], today: String) -> [PlannerListRow] {
        let ids = Set(items.map { $0.id })
        let nested = items.filter { $0.parentId != nil && ids.contains($0.parentId!) }
        let stepsByParent = Dictionary(grouping: nested, by: { $0.parentId! })
        let top = items.filter { !($0.parentId != nil && ids.contains($0.parentId!)) }
        var rows = [PlannerListRow]()
        for item in PlannerListing.ordered(top, today: today) {
            rows.append(PlannerListRow(item: item, depth: 0, progress: progress(of: item, in: items)))
            let steps = (stepsByParent[item.id] ?? []).sorted {
                $0.dueDate != $1.dueDate ? $0.dueDate < $1.dueDate : $0.createdAt < $1.createdAt
            }
            rows += steps.map { PlannerListRow(item: $0, depth: 1, progress: nil) }
        }
        return rows
    }
}
