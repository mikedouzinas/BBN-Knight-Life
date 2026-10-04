//
//  PlannerCalendarIndexTests.swift
//  BBNDailyTests
//
//  HQ-2183. Which dots a day gets, which items list under it, and that school key dates plug in
//  as read-only without the calendar knowing.
//

import XCTest
@testable import BBNDaily

final class PlannerCalendarIndexTests: XCTestCase {

    private let today = "2026-10-20"

    private func item(_ id: String, _ kind: PlannerKind, _ day: String, completed: Bool = false) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: day, completed: completed)
    }

    func testADayWithNothingHasNoDots() {
        let index = PlannerCalendarIndex(items: [item("a", .test, "2026-10-21")])
        XCTAssertEqual(index.kinds(onDay: "2026-10-22"), [])
        XCTAssertEqual(index.items(onDay: "2026-10-22", today: today), [])
        XCTAssertEqual(index.openCount(onDay: "2026-10-22"), 0)
    }

    func testOneDotPerKindNotPerItem() {
        let index = PlannerCalendarIndex(items: [item("a", .test, "2026-10-21"), item("b", .test, "2026-10-21")])
        XCTAssertEqual(index.kinds(onDay: "2026-10-21"), [.test])
        XCTAssertEqual(index.openCount(onDay: "2026-10-21"), 2)
    }

    func testDotsComeInAFixedOrderWhateverOrderTheItemsArrive() {
        let items = [item("a", .appointment, "2026-10-21"), item("b", .test, "2026-10-21"), item("c", .sports, "2026-10-21")]
        XCTAssertEqual(PlannerCalendarIndex(items: items).kinds(onDay: "2026-10-21"), [.test, .sports, .appointment])
        XCTAssertEqual(PlannerCalendarIndex(items: items.reversed()).kinds(onDay: "2026-10-21"), [.test, .sports, .appointment])
    }

    func testDotsAreCappedAtThree() {
        let items = PlannerKind.allCases.map { item($0.rawValue, $0, "2026-10-21") }
        XCTAssertEqual(items.count, 4)
        let kinds = PlannerCalendarIndex(items: items).kinds(onDay: "2026-10-21")
        XCTAssertEqual(kinds.count, PlannerCalendarIndex.maxDotsPerDay)
        XCTAssertEqual(kinds, [.test, .homework, .sports], "the first three in fixed order")
    }

    func testACompletedItemLeavesNoDotButStillListsOnItsDay() {
        let index = PlannerCalendarIndex(items: [item("done", .test, "2026-10-21", completed: true)])
        XCTAssertEqual(index.kinds(onDay: "2026-10-21"), [])
        XCTAssertEqual(index.openCount(onDay: "2026-10-21"), 0)
        XCTAssertEqual(index.items(onDay: "2026-10-21", today: today).map { $0.id }, ["done"], "still there to reopen")
    }

    func testOnlyThatDaysItemsList() {
        let index = PlannerCalendarIndex(items: [item("a", .test, "2026-10-21"), item("b", .homework, "2026-10-22")])
        XCTAssertEqual(index.items(onDay: "2026-10-21", today: today).map { $0.id }, ["a"])
    }

    func testAWeekendAndABreakDayStillGetTheirItems() {
        // 2026-10-24 is a Saturday. The calendar must not drop an item because it is not a school day.
        let index = PlannerCalendarIndex(items: [item("game", .sports, "2026-10-24")])
        XCTAssertEqual(index.kinds(onDay: "2026-10-24"), [.sports])
    }

    // MARK: - School key dates

    private struct StubKeyDates: SchoolKeyDateSource {
        var returned: [PlannerItem]
        func keyDates(from startDay: String, through endDay: String) -> [PlannerItem] { returned }
    }

    func testSchoolKeyDatesPlugInAsReadOnlyItemsWithoutTheCalendarKnowing() {
        let keyDate = PlannerItem(id: PlannerItem.keyDateIDPrefix + "midterms", kind: .test, title: "Midterms begin", dueDate: "2026-10-26")
        let index = PlannerCalendarIndex(items: [], keyDateSources: [StubKeyDates(returned: [keyDate])],
                                         from: "2026-10-01", through: "2026-10-31")
        let listed = index.items(onDay: "2026-10-26", today: today)
        XCTAssertEqual(listed.map { $0.title }, ["Midterms begin"])
        XCTAssertTrue(listed[0].isSchoolKeyDate, "a key date must be recognisable as read-only")
        XCTAssertEqual(index.kinds(onDay: "2026-10-26"), [.test])
    }

    func testAStudentsOwnItemIsNeverMistakenForAKeyDate() {
        // Firestore auto ids are letters and digits; none starts with the prefix.
        XCTAssertFalse(item("aB3xYz9Qw1LmN0pRsT4u", .test, "2026-10-21").isSchoolKeyDate)
        XCTAssertTrue(PlannerItem(id: "keydate:x", kind: .test, title: "t", dueDate: "2026-10-21").isSchoolKeyDate)
    }

    func testNoKeyDateSourcesIsTheDefaultAndChangesNothing() {
        let index = PlannerCalendarIndex(items: [item("a", .test, "2026-10-21")], from: "2026-10-01", through: "2026-10-31")
        XCTAssertEqual(index.items(onDay: "2026-10-21", today: today).count, 1)
    }
}

final class PlannerCalendarWindowTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let page = Date(timeIntervalSince1970: 1_792_497_600)   // 2026-10-20

    func testNeededIsInsideWhatIsLoaded() {
        let needed = PlannerCalendarWindow.needed(forPage: page, timeZone: utc)
        let load = PlannerCalendarWindow.toLoad(forPage: page, timeZone: utc)
        XCTAssertTrue(PlannerCalendarWindow.covers(load, needed))
        XCTAssertEqual(needed.start, "2026-09-15")
        XCTAssertEqual(needed.end, "2026-12-01")
        XCTAssertEqual(load.start, "2026-08-06")
        XCTAssertEqual(load.end, "2027-02-17")
    }

    func testSwipingASmallDistanceStaysCoveredAndALargeOneDoesNot() {
        let load = PlannerCalendarWindow.toLoad(forPage: page, timeZone: utc)
        let nextMonth = page.addingTimeInterval(30 * 86_400)
        XCTAssertTrue(PlannerCalendarWindow.covers(load, PlannerCalendarWindow.needed(forPage: nextMonth, timeZone: utc)),
                      "one month on needs no new read")
        let farAway = page.addingTimeInterval(200 * 86_400)
        XCTAssertFalse(PlannerCalendarWindow.covers(load, PlannerCalendarWindow.needed(forPage: farAway, timeZone: utc)),
                       "months away does")
    }

    func testCoversIsStrict() {
        XCTAssertTrue(PlannerCalendarWindow.covers(("2026-01-01", "2026-12-31"), ("2026-01-01", "2026-12-31")))
        XCTAssertFalse(PlannerCalendarWindow.covers(("2026-01-02", "2026-12-31"), ("2026-01-01", "2026-12-31")))
        XCTAssertFalse(PlannerCalendarWindow.covers(("2026-01-01", "2026-12-30"), ("2026-01-01", "2026-12-31")))
    }
}
