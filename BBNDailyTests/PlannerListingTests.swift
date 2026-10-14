//
//  PlannerListingTests.swift
//  BBNDailyTests
//
//  HQ-2181. The decisions behind the Upcoming list and the add/edit sheet: order, overdue,
//  wording, and how the sheet becomes an item without losing what it does not show.
//

import XCTest
@testable import BBNDaily

final class PlannerListingTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let la = TimeZone(identifier: "America/Los_Angeles")!
    /// 2026-10-20 12:00 UTC: the 20th everywhere that matters to these tests.
    private let now = Date(timeIntervalSince1970: 1_792_497_600)
    private let today = "2026-10-20"

    private func item(_ id: String, _ day: String, completed: Bool = false, created: TimeInterval = 0,
                      title: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: .homework, title: title ?? id, dueDate: day, completed: completed,
                    createdAt: Date(timeIntervalSince1970: created))
    }

    // MARK: - Overdue

    func testOverdueMeansNotDoneAndBeforeToday() {
        XCTAssertTrue(PlannerListing.isOverdue(item("a", "2026-10-19"), today: today))
        XCTAssertFalse(PlannerListing.isOverdue(item("a", today), today: today), "due today is not overdue")
        XCTAssertFalse(PlannerListing.isOverdue(item("a", "2026-10-21"), today: today))
        XCTAssertFalse(PlannerListing.isOverdue(item("a", "2026-10-01", completed: true), today: today), "done is never overdue")
    }

    // MARK: - Order

    func testOrderIsOverdueThenUpcomingThenDone() {
        let list = [
            item("upcomingLate", "2026-10-30"),
            item("done", "2026-10-25", completed: true),
            item("overdueNew", "2026-10-19"),
            item("upcomingSoon", "2026-10-21"),
            item("overdueOld", "2026-10-10"),
        ]
        XCTAssertEqual(PlannerListing.ordered(list, today: today).map { $0.id },
                       ["overdueOld", "overdueNew", "upcomingSoon", "upcomingLate", "done"])
    }

    func testCompletedItemsRunNewestFirst() {
        let list = [item("old", "2026-10-01", completed: true), item("recent", "2026-10-18", completed: true)]
        XCTAssertEqual(PlannerListing.ordered(list, today: today).map { $0.id }, ["recent", "old"])
    }

    func testTiesAreStableBySpecificRule() {
        let list = [item("b", today, created: 2, title: "B"), item("a", today, created: 1, title: "Z"),
                    item("c", today, created: 2, title: "A")]
        // Same day: older creation first, then title.
        XCTAssertEqual(PlannerListing.ordered(list, today: today).map { $0.id }, ["a", "c", "b"])
        XCTAssertEqual(PlannerListing.ordered(list.reversed(), today: today).map { $0.id }, ["a", "c", "b"],
                       "the same answer whatever order they arrive in")
    }

    func testEmptyListIsFine() { XCTAssertEqual(PlannerListing.ordered([], today: today), []) }

    // MARK: - Wording

    func testRelativeDays() {
        func label(_ day: String) -> String { PlannerListing.dayLabel(forDay: day, now: now, timeZone: utc, locale: Locale(identifier: "en_US")) }
        XCTAssertEqual(label("2026-10-20"), "Today")
        XCTAssertEqual(label("2026-10-21"), "Tomorrow")
        XCTAssertEqual(label("2026-10-19"), "Yesterday")
        XCTAssertFalse(["Today", "Tomorrow", "Yesterday"].contains(label("2026-10-27")))
        XCTAssertTrue(label("2026-10-27").contains("27"), label("2026-10-27"))
    }

    func testRelativeDaysFollowThePhonesTimeZone() {
        // 2026-10-21 03:00 UTC: already the 21st in UTC, still the 20th in Los Angeles.
        let lateNight = Date(timeIntervalSince1970: 1_792_551_600)
        XCTAssertEqual(PlannerListing.dayLabel(forDay: "2026-10-21", now: lateNight, timeZone: utc), "Today")
        XCTAssertEqual(PlannerListing.dayLabel(forDay: "2026-10-21", now: lateNight, timeZone: la), "Tomorrow")
    }

    func testAnUnparseableDayIsShownAsIs() {
        XCTAssertEqual(PlannerListing.dayLabel(forDay: "garbage", now: now, timeZone: utc), "garbage")
    }

    func testSubtitle() {
        let overdue = PlannerItem(id: "1", kind: .test, title: "Chem", dueDate: "2026-10-19", classBlock: "C")
        XCTAssertEqual(PlannerListing.subtitle(for: overdue, today: today, now: now, timeZone: utc, locale: Locale(identifier: "en_US")),
                       "Overdue · Yesterday · Test · Block C")
        let plain = PlannerItem(id: "2", kind: .sports, title: "Game", dueDate: "2026-10-21")
        XCTAssertEqual(PlannerListing.subtitle(for: plain, today: today, now: now, timeZone: utc, locale: Locale(identifier: "en_US")),
                       "Tomorrow · Sports")
    }

    func testEveryKindHasALabel() {
        for kind in PlannerKind.allCases { XCTAssertFalse(kind.label.isEmpty) }
    }

    // MARK: - Load window

    func testLoadWindowIsAMonthBackAndSixMonthsForward() {
        let window = PlannerListing.loadWindow(now: now, timeZone: utc)
        XCTAssertEqual(window.start, "2026-09-20")
        XCTAssertEqual(window.end, "2027-04-18")
        XCTAssertLessThan(window.start, window.end)
    }

    // MARK: - Draft to item

    func testANewDraftStartsAsHomeworkDueTomorrow() {
        let draft = PlannerDraft.new(now: now, timeZone: utc)
        XCTAssertEqual(draft.kind, .homework)
        XCTAssertEqual(PlannerItem.dayString(from: draft.dueDate, timeZone: utc), "2026-10-21")
        XCTAssertEqual(draft.title, "")
    }

    func testMakeItemTrimsAndMapsFields() {
        var draft = PlannerDraft.new(now: now, timeZone: utc)
        draft.kind = .test
        draft.title = "  Chem unit 4  "
        draft.classBlock = "C"
        draft.notes = "  bring calculator \n"
        let made = draft.makeItem(id: "x", now: now, timeZone: utc)
        XCTAssertEqual(made.title, "Chem unit 4")
        XCTAssertEqual(made.notes, "bring calculator")
        XCTAssertEqual(made.kind, .test)
        XCTAssertEqual(made.classBlock, "C")
        XCTAssertEqual(made.dueDate, "2026-10-21")
        XCTAssertEqual(made.createdAt, now)
        XCTAssertFalse(made.completed)
        XCTAssertNil(made.validationError())
    }

    func testBlankNotesBecomeNilSoTheyAreNotWritten() {
        var draft = PlannerDraft.new(now: now, timeZone: utc)
        draft.title = "x"
        draft.notes = "   "
        XCTAssertNil(draft.makeItem(id: "x", now: now, timeZone: utc).notes)
    }

    /// The bug this guards against: rebuilding an edited item from the sheet alone would
    /// un-complete it and orphan a step every time someone fixed a typo.
    func testEditingKeepsEverythingTheSheetDoesNotShow() {
        let original = PlannerItem(id: "keep", kind: .test, title: "Chem", dueDate: "2026-10-25", dueTime: "09:30",
                                   classBlock: "C", notes: "n", completed: true,
                                   createdAt: Date(timeIntervalSince1970: 100), parentId: "parent", isBig: true)
        var draft = PlannerDraft(editing: original, timeZone: utc)
        draft.title = "Chem unit 4"
        let edited = draft.makeItem(id: original.id, replacing: original, now: now, timeZone: utc)
        XCTAssertEqual(edited.title, "Chem unit 4")
        XCTAssertTrue(edited.completed)
        XCTAssertEqual(edited.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(edited.parentId, "parent")
        XCTAssertTrue(edited.isBig)
        XCTAssertEqual(edited.dueTime, "09:30")
        XCTAssertEqual(edited.dueDate, "2026-10-25", "an unchanged date survives the round trip through the picker")
    }

    func testEditingPreFillsTheSheet() {
        let original = PlannerItem(id: "e", kind: .sports, title: "Game", dueDate: "2026-11-02", classBlock: "B", notes: "away")
        let draft = PlannerDraft(editing: original, timeZone: utc)
        XCTAssertEqual(draft.kind, .sports)
        XCTAssertEqual(draft.title, "Game")
        XCTAssertEqual(draft.classBlock, "B")
        XCTAssertEqual(draft.notes, "away")
        XCTAssertEqual(PlannerItem.dayString(from: draft.dueDate, timeZone: utc), "2026-11-02")
    }

    func testAnEmptyTitleDraftFailsValidationRatherThanSaving() {
        let draft = PlannerDraft.new(now: now, timeZone: utc)
        XCTAssertEqual(draft.makeItem(id: "x", now: now, timeZone: utc).validationError(), .emptyTitle)
    }
}
