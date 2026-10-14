//
//  PlannerStepsTests.swift
//  BBNDailyTests
//
//  HQ-2187. The date maths of a split, the rules that keep a step from outliving its parent, the
//  progress count, the order of the list with steps under their parents, and the deletion wording.
//

import XCTest
@testable import BBNDaily

final class PlannerStepsTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let ny = TimeZone(identifier: "America/New_York")!
    private let today = "2026-10-04"

    private func suggest(due: String, count: Int = 4, today: String? = nil, zone: TimeZone? = nil, title: String = "Chem paper") -> [StepSuggestion] {
        PlannerSteps.suggest(parentTitle: title, dueDate: due, today: today ?? self.today, count: count, timeZone: zone ?? utc)
    }
    private func item(_ id: String, _ due: String, parent: String? = nil, completed: Bool = false, created: TimeInterval = 0) -> PlannerItem {
        PlannerItem(id: id, kind: .homework, title: id, dueDate: due, completed: completed,
                    createdAt: Date(timeIntervalSince1970: created), parentId: parent)
    }

    // MARK: - Suggesting dates

    /// The ticket's example: a paper due in 10 days with 4 steps.
    func testTenDaysOutWithFourSteps() {
        XCTAssertEqual(suggest(due: "2026-10-14").map { $0.dueDate }, ["2026-10-07", "2026-10-09", "2026-10-12", "2026-10-14"])
    }

    func testTheLastStepLandsOnTheDueDateAndNoneIsEverAfterIt() {
        for days in 1...40 {
            let due = PlannerItem.dayString(from: PlannerItem.date(fromDay: today, timeZone: utc)!.addingTimeInterval(Double(days) * 86_400), timeZone: utc)
            for count in 1...8 {
                let dates = suggest(due: due, count: count).map { $0.dueDate }
                XCTAssertEqual(dates.last, due, "\(days) days, \(count) steps")
                XCTAssertTrue(dates.allSatisfy { $0 <= due && $0 > today }, "\(days) days, \(count) steps: \(dates)")
                XCTAssertEqual(dates, dates.sorted(), "in order")
                XCTAssertEqual(Set(dates).count, dates.count, "one step a day at most: \(dates)")
            }
        }
    }

    /// Three days out and four steps asked for: only three days exist, so three steps.
    func testNeverMoreStepsThanDays() {
        XCTAssertEqual(suggest(due: "2026-10-07", count: 4).map { $0.dueDate }, ["2026-10-05", "2026-10-06", "2026-10-07"])
        XCTAssertEqual(suggest(due: "2026-10-05", count: 4).map { $0.dueDate }, ["2026-10-05"], "due tomorrow: one step")
    }

    func testDueTodayOrPastHasNoRoom() {
        XCTAssertEqual(suggest(due: "2026-10-04"), [], "due today")
        XCTAssertEqual(suggest(due: "2026-10-01"), [], "already past")
    }

    func testAskingForNoStepsOrAnImpossibleDateGivesNone() {
        XCTAssertEqual(suggest(due: "2026-10-14", count: 0), [])
        XCTAssertEqual(suggest(due: "2026-10-14", count: -2), [])
        XCTAssertEqual(suggest(due: "2026-02-30"), [])
        XCTAssertEqual(suggest(due: "2026-10-14", today: "garbage"), [])
    }

    func testTheCountIsCappedAtSix() {
        XCTAssertEqual(suggest(due: "2026-12-31", count: 50).count, PlannerSteps.maxSteps)
    }

    func testSpacingIsAsEvenAsWholeDaysAllow() {
        let dates = suggest(due: "2026-10-14", count: 4).map { PlannerItem.date(fromDay: $0.dueDate, timeZone: utc)! }
        let gaps = zip(dates, dates.dropFirst()).map { Int($1.timeIntervalSince($0) / 86_400) }
        XCTAssertLessThanOrEqual((gaps.max() ?? 0) - (gaps.min() ?? 0), 1, "gaps \(gaps)")
    }

    func testStepsAcrossAMonthAndAYearBoundary() {
        XCTAssertEqual(suggest(due: "2026-11-03", count: 2, today: "2026-10-30").map { $0.dueDate }, ["2026-11-01", "2026-11-03"])
        XCTAssertEqual(suggest(due: "2027-01-03", count: 2, today: "2026-12-29").map { $0.dueDate }, ["2027-01-01", "2027-01-03"])
    }

    func testStepsAcrossADaylightSavingChangeLandOnTheRightDates() {
        // The US falls back on 2026-11-01, a 25-hour day. Three calendar days after Oct 30 is Nov 2, but
        // 3 x 86,400 seconds after Oct 30 midnight is still Nov 1 (23:00), so a version that added
        // seconds would put the second step on the wrong date. This is that case.
        XCTAssertEqual(suggest(due: "2026-11-04", count: 4, today: "2026-10-30", zone: ny).map { $0.dueDate },
                       ["2026-10-31", "2026-11-02", "2026-11-03", "2026-11-04"])
    }

    func testTitlesAreNumberedAndFitTheTitleLimit() {
        XCTAssertEqual(suggest(due: "2026-10-14").map { $0.title }, ["Chem paper: step 1 of 4", "Chem paper: step 2 of 4", "Chem paper: step 3 of 4", "Chem paper: step 4 of 4"])
        let long = String(repeating: "x", count: FieldLimits.plannerTitle)
        for suggestion in suggest(due: "2026-10-14", title: long) {
            XCTAssertLessThanOrEqual(suggestion.title.count, FieldLimits.plannerTitle)
            XCTAssertTrue(suggestion.title.hasSuffix("step \(suggestion.title.last == "4" ? 4 : 0) of 4") || suggestion.title.contains(": step "))
            XCTAssertNil(PlannerItem(id: "x", kind: .homework, title: suggestion.title, dueDate: suggestion.dueDate, parentId: "p").validationError())
        }
    }

    func testAStepIsTheParentsKindAndClassNeverBigAndHasTheOrdinaryReminder() {
        let parent = PlannerItem(id: "p", kind: .test, title: "Chem", dueDate: "2026-10-14", classBlock: "C", isBig: true)
        let steps = PlannerSteps.makeSteps(for: parent, suggestions: suggest(due: "2026-10-14"), ids: ["a", "b", "c", "d"])
        XCTAssertEqual(steps.count, 4)
        for step in steps {
            XCTAssertEqual(step.parentId, "p")
            XCTAssertEqual(step.kind, .test)
            XCTAssertEqual(step.classBlock, "C")
            XCTAssertFalse(step.isBig, "the countdown is the parent's")
            XCTAssertEqual(step.reminder, .evening)
            XCTAssertFalse(step.completed)
            XCTAssertNil(step.validationError())
        }
        XCTAssertEqual(steps.map { $0.id }, ["a", "b", "c", "d"])
    }

    // MARK: - A step never outlives its parent

    func testAStepDatedAfterItsParentIsRefusedWithAReason() {
        let parent = item("p", "2026-10-20")
        XCTAssertNotNil(PlannerSteps.dateProblem(step: item("s", "2026-10-21", parent: "p"), parent: parent))
        XCTAssertNil(PlannerSteps.dateProblem(step: item("s", "2026-10-20", parent: "p"), parent: parent), "the same day is fine")
        XCTAssertNil(PlannerSteps.dateProblem(step: item("s", "2026-10-10", parent: "p"), parent: parent))
        XCTAssertNil(PlannerSteps.dateProblem(step: item("s", "2026-10-21", parent: "p"), parent: nil), "no parent loaded: nothing to compare")
    }

    func testMovingTheParentEarlierMovesOnlyTheStepsThatWouldBeLate() {
        let steps = [item("a", "2026-10-08", parent: "p"), item("b", "2026-10-12", parent: "p"), item("c", "2026-10-16", parent: "p"), item("d", "2026-10-20", parent: "p")]
        let moved = PlannerSteps.reconcile(steps: steps, toParentDue: "2026-10-14")
        XCTAssertEqual(moved.map { $0.id }, ["c", "d"])
        XCTAssertEqual(moved.map { $0.dueDate }, ["2026-10-14", "2026-10-14"])
    }

    func testMovingTheParentLaterOrNotAtAllMovesNothing() {
        let steps = [item("a", "2026-10-08", parent: "p"), item("b", "2026-10-20", parent: "p")]
        XCTAssertEqual(PlannerSteps.reconcile(steps: steps, toParentDue: "2026-10-25"), [])
        XCTAssertEqual(PlannerSteps.reconcile(steps: steps, toParentDue: "2026-10-20"), [], "a step on the new date is not late")
    }

    func testAFinishedStepIsMovedTooBecauseTheRuleIsAboutThePlan() {
        let moved = PlannerSteps.reconcile(steps: [item("a", "2026-10-20", parent: "p", completed: true)], toParentDue: "2026-10-14")
        XCTAssertEqual(moved.map { $0.dueDate }, ["2026-10-14"])
        XCTAssertTrue(moved[0].completed, "and it stays finished")
    }

    /// After a reconcile no step is later than the parent: the invariant, over many shapes.
    func testAfterReconcilingNoStepIsEverAfterTheParent() {
        let days = (1...28).map { String(format: "2026-10-%02d", $0) }
        for newDue in days {
            let steps = days.enumerated().map { item("s\($0.offset)", $0.element, parent: "p") }
            let fixed = PlannerSteps.reconcile(steps: steps, toParentDue: newDue)
            let result = steps.map { step in fixed.first { $0.id == step.id } ?? step }
            XCTAssertTrue(result.allSatisfy { $0.dueDate <= newDue }, "parent due \(newDue)")
        }
    }

    // MARK: - One level only

    func testOnlyATopLevelItemCanHaveSteps() {
        XCTAssertTrue(PlannerSteps.canHaveSteps(item("p", "2026-10-20")))
        XCTAssertFalse(PlannerSteps.canHaveSteps(item("s", "2026-10-20", parent: "p")), "a step cannot have steps")
        XCTAssertFalse(PlannerSteps.canHaveSteps(PlannerItem(id: PlannerItem.keyDateIDPrefix + "x", kind: .test, title: "k", dueDate: "2026-10-20")), "a school key date is read-only")
    }

    func testAStepCannotBeBigAtTheModelLevel() {
        var step = item("s", "2026-10-20", parent: "p")
        step.isBig = true
        XCTAssertEqual(step.validationError(), .stepCannotBeBig)
        step.parentId = nil
        XCTAssertNil(step.validationError(), "a parent can be big")
    }

    // MARK: - Progress, and finishing every step is not finishing the parent

    func testProgressCountsDoneStepsOfThisParentOnly() {
        let parent = item("p", "2026-10-20")
        let items = [parent, item("a", "2026-10-10", parent: "p", completed: true), item("b", "2026-10-12", parent: "p", completed: true),
                     item("c", "2026-10-14", parent: "p"), item("d", "2026-10-16", parent: "p"), item("other", "2026-10-11", parent: "q", completed: true)]
        XCTAssertEqual(PlannerSteps.progress(of: parent, in: items), "2 of 4 steps done")
    }

    func testProgressWordingAndNoStepsMeansNoLine() {
        let parent = item("p", "2026-10-20")
        XCTAssertNil(PlannerSteps.progress(of: parent, in: [parent]))
        XCTAssertEqual(PlannerSteps.progress(of: parent, in: [parent, item("a", "2026-10-10", parent: "p")]), "0 of 1 step done")
    }

    func testEveryStepDoneDoesNotFinishTheParent() {
        let parent = item("p", "2026-10-20")
        let items = [parent] + (1...3).map { item("s\($0)", "2026-10-1\($0)", parent: "p", completed: true) }
        XCTAssertEqual(PlannerSteps.progress(of: parent, in: items), "3 of 3 steps done")
        XCTAssertFalse(parent.completed, "finishing the thing is the student's call")
        XCTAssertFalse(items[0].completed)
    }

    // MARK: - Context

    func testContextFindsTheParentOfAStepAndTheStepsOfAParent() {
        let parent = item("p", "2026-10-20")
        let late = item("b", "2026-10-15", parent: "p", created: 2), early = item("a", "2026-10-10", parent: "p", created: 1)
        let items = [parent, late, early, item("x", "2026-10-11")]
        XCTAssertEqual(PlannerSteps.context(for: parent, in: items).steps.map { $0.id }, ["a", "b"], "soonest first")
        XCTAssertEqual(PlannerSteps.context(for: early, in: items).parent?.id, "p")
        XCTAssertEqual(PlannerSteps.context(for: item("x", "2026-10-11"), in: items), .none)
        XCTAssertNil(PlannerSteps.context(for: item("s", "2026-10-11", parent: "gone"), in: items).parent, "parent not loaded")
    }

    // MARK: - Deleting a parent

    func testTheDeleteConfirmationSaysHowManyStepsGoWithIt() {
        XCTAssertEqual(PlannerSteps.deleteMessage(parentTitle: "Chem paper", stepCount: 4), "Delete \"Chem paper\" and its 4 steps? This can't be undone.")
        XCTAssertEqual(PlannerSteps.deleteMessage(parentTitle: "Chem paper", stepCount: 1), "Delete \"Chem paper\" and its 1 step? This can't be undone.")
        XCTAssertEqual(PlannerSteps.deleteMessage(parentTitle: "Chem paper", stepCount: 0), "Delete \"Chem paper\"?")
    }

    // MARK: - The Upcoming list

    private let listToday = "2026-10-20"

    func testStepsSitDirectlyUnderTheirParentWithItsProgress() {
        let items = [item("p", "2026-11-10"), item("s2", "2026-11-05", parent: "p"), item("s1", "2026-10-25", parent: "p", completed: true),
                     item("solo", "2026-10-30")]
        let rows = PlannerSteps.rows(items, today: listToday)
        XCTAssertEqual(rows.map { $0.item.id }, ["solo", "p", "s1", "s2"], "solo is sooner; p's steps follow p, by their own dates")
        XCTAssertEqual(rows.map { $0.depth }, [0, 0, 1, 1])
        XCTAssertEqual(rows[1].progress, "1 of 2 steps done")
        XCTAssertNil(rows[0].progress)
        XCTAssertNil(rows[2].progress)
    }

    func testAStepWhoseParentIsNotLoadedIsShownAsAnOrdinaryItemNotLost() {
        let rows = PlannerSteps.rows([item("orphan", "2026-10-25", parent: "gone")], today: listToday)
        XCTAssertEqual(rows.map { $0.item.id }, ["orphan"])
        XCTAssertEqual(rows.map { $0.depth }, [0])
    }

    func testAnOverdueParentLeadsAndItsFutureStepsStillFollowIt() {
        let items = [item("future", "2026-10-25"), item("late", "2026-10-10"), item("step", "2026-10-30", parent: "late")]
        XCTAssertEqual(PlannerSteps.rows(items, today: listToday).map { $0.item.id }, ["late", "step", "future"])
    }

    func testACompletedParentSinksWithItsStepsUnderIt() {
        let items = [item("done", "2026-10-22", completed: true), item("ds", "2026-10-21", parent: "done"), item("open", "2026-11-30")]
        XCTAssertEqual(PlannerSteps.rows(items, today: listToday).map { $0.item.id }, ["open", "done", "ds"])
    }

    func testEveryItemAppearsExactlyOnce() {
        let items = [item("p", "2026-11-10"), item("a", "2026-10-25", parent: "p"), item("b", "2026-10-26", parent: "p"), item("q", "2026-10-30"), item("o", "2026-10-21", parent: "gone")]
        let ids = PlannerSteps.rows(items, today: listToday).map { $0.item.id }
        XCTAssertEqual(ids.sorted(), items.map { $0.id }.sorted())
    }

    func testNoItemsNoRows() { XCTAssertEqual(PlannerSteps.rows([], today: listToday), []) }
}
