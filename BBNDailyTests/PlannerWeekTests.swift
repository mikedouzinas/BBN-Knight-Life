//
//  PlannerWeekTests.swift
//  BBNDailyTests
//
//  HQ-2184. Which week to show, which five days, what lands on each, and how heavy a day is.
//

import XCTest
@testable import BBNDaily

final class PlannerWeekTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let la = TimeZone(identifier: "America/Los_Angeles")!

    /// 2026-10-05 is a Monday.
    private func date(_ day: String, _ zone: TimeZone? = nil) -> Date { PlannerItem.date(fromDay: day, timeZone: zone ?? utc)! }
    private func day(_ date: Date, _ zone: TimeZone? = nil) -> String { PlannerItem.dayString(from: date, timeZone: zone ?? utc) }

    private func item(_ id: String, _ kind: PlannerKind, _ dueDate: String, completed: Bool = false, big: Bool = false) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: dueDate, completed: completed, isBig: big)
    }

    // MARK: - Which Monday

    func testAWeekdayShowsThisWeeksMonday() {
        for d in ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"] {
            XCTAssertEqual(day(PlannerWeek.monday(for: date(d), timeZone: utc)), "2026-10-05", d)
        }
    }

    func testAWeekendShowsNextWeek() {
        XCTAssertEqual(day(PlannerWeek.monday(for: date("2026-10-10"), timeZone: utc)), "2026-10-12", "Saturday")
        XCTAssertEqual(day(PlannerWeek.monday(for: date("2026-10-11"), timeZone: utc)), "2026-10-12", "Sunday")
    }

    /// 23:59 on a Monday in Los Angeles is already Tuesday in UTC. The week is decided in the
    /// phone's own zone, so it must still be that Monday's week.
    func testALateMondayNightInTheStudentsZoneIsStillThatMonday() {
        let lateMonday = PlannerItem.date(fromDay: "2026-10-05", timeZone: la)!.addingTimeInterval(23 * 3600 + 59 * 60)
        XCTAssertEqual(day(PlannerWeek.monday(for: lateMonday, timeZone: la), la), "2026-10-05")
        XCTAssertEqual(day(PlannerWeek.monday(for: lateMonday, timeZone: utc), utc), "2026-10-05",
                       "and it is Tuesday in UTC, still the same school week")
    }

    func testShiftingByWeeks() {
        let monday = date("2026-10-05")
        XCTAssertEqual(day(PlannerWeek.shift(monday, byWeeks: 1, timeZone: utc)), "2026-10-12")
        XCTAssertEqual(day(PlannerWeek.shift(monday, byWeeks: -1, timeZone: utc)), "2026-09-28")
        XCTAssertEqual(day(PlannerWeek.shift(monday, byWeeks: 0, timeZone: utc)), "2026-10-05")
    }

    func testAWeekAcrossAMonthBoundaryAndADSTChange() {
        // The week of Mon 2026-11-02 contains the 2026-11-01 clock change's aftermath in the US;
        // days must still be Mon-Fri, one day apart, with no skipped or doubled date.
        let days = PlannerWeek.days(startingMonday: date("2026-11-02", la), items: [], today: "2026-11-02", timeZone: la) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(days.map { $0.day }, ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"])
        let crossing = PlannerWeek.days(startingMonday: date("2026-10-26", la), items: [], today: "x", timeZone: la) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(crossing.map { $0.day }, ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30"])
        let monthEnd = PlannerWeek.days(startingMonday: date("2026-09-28", utc), items: [], today: "x", timeZone: utc) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(monthEnd.map { $0.day }, ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02"])
    }

    // MARK: - What lands on each day

    func testItemsLandOnTheirOwnDayAndNoOtherAndWeekendItemsAreNotShown() {
        let items = [item("mon", .homework, "2026-10-05"), item("wed", .test, "2026-10-07"), item("sat", .sports, "2026-10-10"),
                     item("nextWeek", .test, "2026-10-12")]
        let days = PlannerWeek.days(startingMonday: date("2026-10-05"), items: items, today: "2026-10-05", timeZone: utc) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(days.map { $0.items.map { $0.id } }, [["mon"], [], ["wed"], [], []])
    }

    func testTheResolverIsAskedOnceForEachOfTheFiveDays() {
        var asked = [String]()
        _ = PlannerWeek.days(startingMonday: date("2026-10-05"), items: [], today: "2026-10-05", timeZone: utc) { date in
            asked.append(PlannerItem.dayString(from: date, timeZone: self.utc))
            return WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(asked, ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"])
    }

    func testANoSchoolDayKeepsItsMessageAndStillShowsItsItems() {
        let days = PlannerWeek.days(startingMonday: date("2026-10-05"), items: [item("a", .homework, "2026-10-12")], today: "x", timeZone: utc) { date in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: "No Class - Columbus Day")
        }
        XCTAssertEqual(days[0].info.emptyMessage, "No Class - Columbus Day")
        let mondayAfter = PlannerWeek.days(startingMonday: date("2026-10-12"), items: [item("a", .homework, "2026-10-12")], today: "x", timeZone: utc) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: "No Class - Columbus Day")
        }
        XCTAssertEqual(mondayAfter[0].items.count, 1, "homework due on a holiday still shows")
    }

    func testItemsOnADayAreInTheUpcomingListOrder() {
        let items = [item("done", .test, "2026-10-06", completed: true), item("open", .homework, "2026-10-06")]
        let days = PlannerWeek.days(startingMonday: date("2026-10-05"), items: items, today: "2026-10-05", timeZone: utc) { _ in
            WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil)
        }
        XCTAssertEqual(days[1].items.map { $0.id }, ["open", "done"], "completed sinks")
    }

    // MARK: - How heavy

    private func weekDay(_ items: [PlannerItem]) -> PlannerWeekDay {
        PlannerWeekDay(day: "2026-10-06", info: WeekDayInfo(weekdayName: "tuesday", classes: [], emptyMessage: nil), items: items)
    }

    func testOnlyOpenTestsAndBigDeadlinesMakeADayHeavy() {
        XCTAssertEqual(weekDay([item("t", .test, "d")]).heavyCount, 1)
        XCTAssertEqual(weekDay([item("b", .homework, "d", big: true)]).heavyCount, 1, "a big deadline counts whatever its kind")
        XCTAssertEqual(weekDay([item("h", .homework, "d"), item("a", .appointment, "d"), item("s", .sports, "d")]).heavyCount, 0)
        XCTAssertEqual(weekDay([item("done", .test, "d", completed: true)]).heavyCount, 0, "finished is not ahead")
        XCTAssertEqual(weekDay([item("t", .test, "d"), item("b", .homework, "d", big: true)]).heavyCount, 2)
    }

    func testHeavyWording() {
        XCTAssertNil(weekDay([]).heavyLabel)
        XCTAssertEqual(weekDay([item("t", .test, "d")]).heavyLabel, "1 test or deadline")
        XCTAssertEqual(weekDay([item("t", .test, "d"), item("u", .test, "d")]).heavyLabel, "2 tests or deadlines")
    }

    func testTheBusyThursdayCase() {
        // The reason this view exists: a test AND a big project due the same day.
        let thursday = weekDay([item("chem", .test, "d"), item("paper", .homework, "d", big: true), item("hw", .homework, "d")])
        XCTAssertEqual(thursday.heavyLabel, "2 tests or deadlines")
    }

    func testNothingPlanned() {
        XCTAssertTrue(weekDay([]).hasNothingPlanned)
        XCTAssertFalse(weekDay([item("a", .homework, "d")]).hasNothingPlanned)
    }

    // MARK: - Rows

    func testRowsAreClassesThenItems() {
        let planned = item("t", .test, "d")
        let day = PlannerWeekDay(day: "d", info: WeekDayInfo(weekdayName: "x", classes: [WeekClass(block: "A", subject: "Precalc"), WeekClass(block: "C", subject: "Chem")], emptyMessage: nil),
                                 items: [planned])
        XCTAssertEqual(day.rows, [.schoolClass(WeekClass(block: "A", subject: "Precalc")), .schoolClass(WeekClass(block: "C", subject: "Chem")), .item(planned)])
    }

    func testANoClassDayShowsItsReasonThenItsItems() {
        let homework = item("h", .homework, "d")
        let day = PlannerWeekDay(day: "d", info: WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: "No Class - Columbus Day"), items: [homework])
        XCTAssertEqual(day.rows, [.note("No Class - Columbus Day"), .item(homework)])
    }

    func testAClasslessDayWithNoReasonHasOnlyItsItems() {
        let day = PlannerWeekDay(day: "d", info: WeekDayInfo(weekdayName: "x", classes: [], emptyMessage: nil), items: [])
        XCTAssertEqual(day.rows, [])
    }

    func testAReasonIsNotShownWhenThereAreClasses() {
        let day = PlannerWeekDay(day: "d", info: WeekDayInfo(weekdayName: "x", classes: [WeekClass(block: "A", subject: "P")], emptyMessage: "stale"), items: [])
        XCTAssertEqual(day.rows, [.schoolClass(WeekClass(block: "A", subject: "P"))])
    }

    // MARK: - Wording

    func testDayTitleAndRange() {
        let en = Locale(identifier: "en_US")
        XCTAssertEqual(PlannerWeek.dayTitle(forDay: "2026-10-06", today: "2026-10-05", timeZone: utc, locale: en), "Tuesday, Oct 6")
        XCTAssertEqual(PlannerWeek.dayTitle(forDay: "2026-10-06", today: "2026-10-06", timeZone: utc, locale: en), "Tuesday, Oct 6 · Today")
        XCTAssertEqual(PlannerWeek.rangeLabel(monday: date("2026-10-05"), timeZone: utc, locale: en), "Oct 5 – Oct 9")
        XCTAssertEqual(PlannerWeek.rangeLabel(monday: date("2026-09-28"), timeZone: utc, locale: en), "Sep 28 – Oct 2")
    }
}

final class PlannerClassRowTests: XCTestCase {

    private func item(_ id: String, _ kind: PlannerKind, block: String?, completed: Bool = false, day: String = "2026-10-06") -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: day, classBlock: block, completed: completed, createdAt: Date(timeIntervalSince1970: 0))
    }
    private func day(_ items: [PlannerItem], classes: [String] = ["A", "C", "E"], reason: String? = nil) -> PlannerWeekDay {
        PlannerWeekDay(day: "2026-10-06",
                       info: WeekDayInfo(weekdayName: "tuesday", classes: classes.map { WeekClass(block: $0, subject: "Class \($0)") }, emptyMessage: reason),
                       items: items)
    }
    private func ids(_ rows: [PlannerWeekDay.Row]) -> [String] {
        rows.map { row in
            switch row {
            case .schoolClass(let c): return "class:\(c.block)"
            case .note(let n): return "note:\(n)"
            case .item(let i): return "item:\(i.id)"
            }
        }
    }

    // MARK: - What goes on a class row

    func testATestOrHomeworkWithAClassThatMeetsThatDayGoesOnThatClassRow() {
        let d = day([item("spanishTest", .test, block: "A"), item("calcHW", .homework, block: "C")])
        XCTAssertEqual(d.itemsOnClassRow("A").map { $0.id }, ["spanishTest"])
        XCTAssertEqual(d.itemsOnClassRow("C").map { $0.id }, ["calcHW"])
        XCTAssertEqual(d.itemsOnClassRow("E"), [])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E"], "nothing left to list below")
    }

    func testSportsAndAppointmentsStayInTheBottomListEvenWithAClass() {
        let d = day([item("game", .sports, block: "A"), item("dentist", .appointment, block: "C")])
        XCTAssertEqual(d.itemsOnClassRow("A"), [])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E", "item:game", "item:dentist"])
    }

    func testAnItemWithNoClassStaysInTheBottomList() {
        let d = day([item("loose", .homework, block: nil), item("looseTest", .test, block: nil)])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E", "item:loose", "item:looseTest"])
    }

    // MARK: - The fallbacks that must not lose an item

    func testAnItemForAClassThatDoesNotMeetThatDayFallsToTheBottom() {
        let d = day([item("gTest", .test, block: "G")])    // G isn't on Tuesday's schedule
        XCTAssertEqual(d.itemsOnClassRow("G"), [])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E", "item:gTest"])
    }

    func testOnANoSchoolDayEverythingIsListBelowTheReasonNotLost() {
        let d = day([item("hw", .homework, block: "A"), item("t", .test, block: "C")], classes: [], reason: "No Class - Columbus Day")
        XCTAssertEqual(ids(d.rows), ["note:No Class - Columbus Day", "item:hw", "item:t"])
    }

    func testBlockLettersCompareCaseInsensitively() {
        let d = day([item("t", .test, block: "a")])
        XCTAssertEqual(d.itemsOnClassRow("A").map { $0.id }, ["t"])
        XCTAssertEqual(d.itemsOnClassRow("a").map { $0.id }, ["t"])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E"])
    }

    // MARK: - Order, and finished items

    func testSeveralItemsOnOneClassShowTestsBeforeHomework() {
        let d = day([item("hw1", .homework, block: "A"), item("test", .test, block: "A"), item("hw2", .homework, block: "A")])
        XCTAssertEqual(d.itemsOnClassRow("A").map { $0.id }, ["test", "hw1", "hw2"])
    }

    func testAFinishedItemStaysOnItsClassRow() {
        let d = day([item("done", .homework, block: "A", completed: true)])
        XCTAssertEqual(d.itemsOnClassRow("A").map { $0.id }, ["done"])
        XCTAssertEqual(ids(d.rows), ["class:A", "class:C", "class:E"])
    }

    // MARK: - Exactly once, everywhere

    func testEveryItemAppearsExactlyOnceAcrossBadgesAndTheBottomList() {
        let items = [item("t1", .test, block: "A"), item("h1", .homework, block: "C"), item("s1", .sports, block: "A"), item("a1", .appointment, block: nil),
                     item("g", .test, block: "G"), item("loose", .homework, block: nil), item("d", .homework, block: "E", completed: true)]
        let d = day(items)
        let onRows = ["A", "C", "E", "G"].flatMap { d.itemsOnClassRow($0).map { $0.id } }
        let below = d.rows.compactMap { row -> String? in if case .item(let i) = row { return i.id } else { return nil } }
        XCTAssertEqual((onRows + below).sorted(), items.map { $0.id }.sorted(), "each once")
        XCTAssertTrue(Set(onRows).isDisjoint(with: Set(below)), "never both")
    }

    func testBadgingChangesNeitherTheHeavyCountNorWhetherTheDayHasAnything() {
        let d = day([item("t", .test, block: "A"), item("h", .homework, block: "C")])
        XCTAssertEqual(d.heavyCount, 1, "a badged test still makes the day heavy")
        XCTAssertFalse(d.hasNothingPlanned)
    }
}
