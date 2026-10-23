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

    /// A step carries its test's kind, but it is part of that test, not a second one.
    func testAStepDoesNotCountAsAnotherDeadline() {
        var step = item("s", .test, "d")
        step.parentId = "t"
        XCTAssertEqual(weekDay([item("t", .test, "d"), step]).heavyCount, 1)
        XCTAssertEqual(weekDay([step]).heavyCount, 0, "a step alone on a day")
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

    // MARK: - The Tomorrow view uses the same rule, on any list of items (HQ-2194)

    func testBadgedItemsTakeOnlyTheDayAndBlockAsked() {
        let items = [item("mon", .test, block: "A", day: "2026-10-05"), item("tue", .test, block: "A", day: "2026-10-06"),
                     item("otherBlock", .test, block: "C", day: "2026-10-05")]
        XCTAssertEqual(PlannerWeekDay.badgedItems(block: "A", day: "2026-10-05", in: items).map { $0.id }, ["mon"])
        XCTAssertEqual(PlannerWeekDay.badgedItems(block: "a", day: "2026-10-05", in: items).map { $0.id }, ["mon"], "case-insensitive")
        XCTAssertEqual(PlannerWeekDay.badgedItems(block: "E", day: "2026-10-05", in: items), [])
    }

    func testBadgedItemsAreTestsAndHomeworkOnlyTestsFirst() {
        let items = [item("hw", .homework, block: "A"), item("game", .sports, block: "A"), item("appt", .appointment, block: "A"), item("test", .test, block: "A")]
        XCTAssertEqual(PlannerWeekDay.badgedItems(block: "A", day: "2026-10-06", in: items).map { $0.id }, ["test", "hw"])
    }

    func testWithoutBadgedRemovesExactlyWhatIsBadgedAndNothingElse() {
        let items = [item("t", .test, block: "A", day: "2026-10-05"),          // badged on A
                     item("laterTest", .test, block: "A", day: "2026-10-20"),  // another day: stays listed
                     item("game", .sports, block: "A", day: "2026-10-05"),     // not a badge kind: stays
                     item("loose", .homework, block: nil, day: "2026-10-05"),  // no class: stays
                     item("gone", .homework, block: "G", day: "2026-10-05")]   // class not being drawn: stays
        let left = PlannerWeekDay.withoutBadged(items, day: "2026-10-05", classBlocks: ["A", "C"])
        XCTAssertEqual(left.map { $0.id }, ["laterTest", "game", "loose", "gone"])
    }

    func testBadgedPlusListedIsEveryItemExactlyOnce() {
        let items = [item("a", .test, block: "A", day: "2026-10-05"), item("b", .homework, block: "C", day: "2026-10-05"),
                     item("c", .homework, block: "C", day: "2026-10-09"), item("d", .appointment, block: nil, day: "2026-10-05")]
        let blocks = ["A", "C"]
        let badged = blocks.flatMap { PlannerWeekDay.badgedItems(block: $0, day: "2026-10-05", in: items).map { $0.id } }
        let listed = PlannerWeekDay.withoutBadged(items, day: "2026-10-05", classBlocks: blocks).map { $0.id }
        XCTAssertEqual((badged + listed).sorted(), ["a", "b", "c", "d"])
    }
}

/// Past days leave the week view (and the arrow back), and a step is never badged away from its test.
final class PlannerPastDaysTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private func item(_ id: String, _ day: String, completed: Bool = false, kind: PlannerKind = .homework,
                      block: String? = nil, parent: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: day, classBlock: block, completed: completed,
                    createdAt: Date(timeIntervalSince1970: 0), parentId: parent)
    }
    /// Monday 2026-10-05 through Friday, each with a class, so a kept past day visibly loses it.
    private func week(_ items: [PlannerItem]) -> [PlannerWeekDay] {
        PlannerWeek.days(startingMonday: PlannerItem.date(fromDay: "2026-10-05", timeZone: utc)!, items: items,
                         today: "2026-10-07", timeZone: utc) { _ in
            WeekDayInfo(weekdayName: "x", classes: [WeekClass(block: "A", subject: "Spanish")], emptyMessage: nil)
        }
    }

    func testDaysBeforeTodayAreDroppedAndTodayOnwardStay() {
        let days = PlannerWeek.hidingPast(week([]), today: "2026-10-07")
        XCTAssertEqual(days.map { $0.day }, ["2026-10-07", "2026-10-08", "2026-10-09"])
    }

    func testAPastDayWithOnlyFinishedItemsIsDropped() {
        let days = PlannerWeek.hidingPast(week([item("done", "2026-10-05", completed: true)]), today: "2026-10-07")
        XCTAssertFalse(days.map { $0.day }.contains("2026-10-05"))
    }

    func testAPastDayWithAnUnfinishedItemStaysShowingOnlyThatItem() {
        let days = PlannerWeek.hidingPast(week([item("open", "2026-10-05"), item("done", "2026-10-05", completed: true)]),
                                          today: "2026-10-07")
        XCTAssertEqual(days.map { $0.day }, ["2026-10-05", "2026-10-07", "2026-10-08", "2026-10-09"])
        XCTAssertEqual(days[0].items.map { $0.id }, ["open"], "the finished one has happened")
        XCTAssertTrue(days[0].info.classes.isEmpty, "its classes are over")
        XCTAssertEqual(days[0].rows.count, 1, "just the open item, no class rows")
    }

    func testAPastTestIsGoneNotOverdue() {
        let days = PlannerWeek.hidingPast(week([item("exam", "2026-10-05", kind: .test)]), today: "2026-10-07")
        XCTAssertFalse(days.map { $0.day }.contains("2026-10-05"))
    }

    func testTodayIsNeverTrimmed() {
        let today = PlannerWeek.hidingPast(week([item("done", "2026-10-07", completed: true)]), today: "2026-10-07")[0]
        XCTAssertEqual(today.items.map { $0.id }, ["done"])
        XCTAssertEqual(today.info.classes.count, 1)
    }

    func testAWeekIsWhollyPastOnlyAfterItsFriday() {
        let monday = PlannerItem.date(fromDay: "2026-09-28", timeZone: utc)!   // Mon-Fri Sep 28 - Oct 2
        XCTAssertTrue(PlannerWeek.isWhollyPast(monday: monday, today: "2026-10-03", timeZone: utc), "Saturday: over")
        XCTAssertFalse(PlannerWeek.isWhollyPast(monday: monday, today: "2026-10-02", timeZone: utc), "Friday itself is not past")
        XCTAssertFalse(PlannerWeek.isWhollyPast(monday: PlannerItem.date(fromDay: "2026-10-05", timeZone: utc)!,
                                                today: "2026-10-07", timeZone: utc))
    }

    // MARK: - A step stays under its test

    func testAStepIsNeverBadgedOnAClassRow() {
        let step = item("study", "2026-10-06", kind: .test, block: "A", parent: "test")
        XCTAssertFalse(PlannerWeekDay.showsOnClassRow(step, classBlocks: ["A"]))
        XCTAssertTrue(PlannerWeekDay.showsOnClassRow(item("test", "2026-10-06", kind: .test, block: "A"), classBlocks: ["A"]))
        XCTAssertEqual(PlannerWeekDay.withoutBadged([step], day: "2026-10-06", classBlocks: ["A"]).map { $0.id }, ["study"],
                       "so it stays in the Upcoming list under its test")
    }
}

/// A class's tests and homework sit inside its block's row on the Schedule tab.
final class PlannerScheduleRowsTests: XCTestCase {

    private func item(_ id: String, _ kind: PlannerKind, block: String?, day: String = "2026-10-07", parent: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: day, classBlock: block, createdAt: Date(timeIntervalSince1970: 0), parentId: parent)
    }
    private let letters = ["A", "N/A", "B", "D"]
    private func attach(_ items: [PlannerItem], has: Set<String> = ["A", "B", "D"], letters: [String]? = nil) -> [[String]] {
        PlannerSchedule.attachments(blockLetters: letters ?? self.letters, hasClass: { has.contains($0) }, items: items, day: "2026-10-07")
            .map { $0.map { $0.id } }
    }

    func testATestGoesInItsBlocksRowAndTestsComeBeforeHomework() {
        let a = attach([item("hw", .homework, block: "B"), item("test", .test, block: "B"), item("other", .test, block: "D")])
        XCTAssertEqual(a, [[], [], ["test", "hw"], ["other"]], "one entry per block, in order")
    }

    func testNothingGoesInANonClassRowOrAClassThatIsNotTheirs() {
        XCTAssertEqual(attach([item("t", .test, block: "A")], has: ["B", "D"]), [[], [], [], []], "A is not their class: the test stays in the list")
    }

    func testOnlyTestsAndHomeworkForThatDayAndNeverSteps() {
        let a = attach([item("game", .sports, block: "A"), item("later", .test, block: "A", day: "2026-10-09"),
                        item("step", .test, block: "A", parent: "t"), item("loose", .homework, block: nil)])
        XCTAssertEqual(a, [[], [], [], []])
    }

    func testALetterThatAppearsTwiceTakesItsItemsOnTheFirstRowOnly() {
        XCTAssertEqual(attach([item("t", .test, block: "D")], letters: ["D", "B", "D"]), [["t"], [], []])
    }

    func testEveryItemIsInItsRowOrInTheListExactlyOnce() {
        let items = [item("a", .test, block: "A"), item("b", .homework, block: "G"), item("c", .sports, block: "A"), item("d", .homework, block: nil)]
        let attachments = PlannerSchedule.attachments(blockLetters: letters, hasClass: { ["A", "B", "D"].contains($0) }, items: items, day: "2026-10-07")
        let inRows = attachments.flatMap { $0.map { $0.id } }
        let left = PlannerSchedule.unattached(items, attachments: attachments).map { $0.id }
        XCTAssertEqual((inRows + left).sorted(), ["a", "b", "c", "d"])
        XCTAssertEqual(inRows, ["a"])
        XCTAssertEqual(left, ["b", "c", "d"])
    }
}

/// A Free block takes any kind of item, on the Schedule and the week view.
final class PlannerFreeBlockTests: XCTestCase {

    private func item(_ id: String, _ kind: PlannerKind, block: String?, parent: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: "2026-10-16", classBlock: block, createdAt: Date(timeIntervalSince1970: 0), parentId: parent)
    }
    private func day(_ items: [PlannerItem]) -> PlannerWeekDay {
        PlannerWeekDay(day: "2026-10-16",
                       info: WeekDayInfo(weekdayName: "friday",
                                         classes: [WeekClass(block: "A", subject: "Spanish"), WeekClass(block: "B", subject: "Free", isFree: true)],
                                         emptyMessage: nil),
                       items: items)
    }

    func testAnyKindOfItemSitsOnAFreeBlockButOnlyTestsAndHomeworkOnAClass() {
        let d = day([item("meet", .appointment, block: "B"), item("game", .sports, block: "B"), item("study", .homework, block: "B"),
                     item("dentist", .appointment, block: "A"), item("exam", .test, block: "A")])
        XCTAssertEqual(d.itemsOnClassRow("B").map { $0.id }, ["study", "meet", "game"], "homework first, then the rest in order")
        XCTAssertEqual(d.itemsOnClassRow("A").map { $0.id }, ["exam"])
    }

    func testEachItemIsOnItsRowOrInTheListExactlyOnce() {
        let items = [item("meet", .appointment, block: "B"), item("dentist", .appointment, block: "A"), item("loose", .appointment, block: nil)]
        let d = day(items)
        let onRows = ["A", "B"].flatMap { d.itemsOnClassRow($0).map { $0.id } }
        let below = d.rows.compactMap { row -> String? in if case .item(let i) = row { return i.id } else { return nil } }
        XCTAssertEqual((onRows + below).sorted(), ["dentist", "loose", "meet"])
        XCTAssertEqual(onRows, ["meet"])
    }

    func testAStepIsNeverPutOnAFreeBlock() {
        XCTAssertTrue(day([item("s", .homework, block: "B", parent: "p")]).itemsOnClassRow("B").isEmpty)
    }

    func testTheScheduleAttachesAnythingToAFreeBlockButNotToAnUnsetOne() {
        let items = [item("meet", .appointment, block: "B"), item("lost", .appointment, block: "C")]
        let a = PlannerSchedule.attachments(blockLetters: ["A", "B", "C"], hasClass: { $0 == "A" }, isFree: { $0 == "B" },
                                            items: items, day: "2026-10-16")
        XCTAssertEqual(a.map { $0.map { $0.id } }, [[], ["meet"], []])
        XCTAssertEqual(PlannerSchedule.unattached(items, attachments: a).map { $0.id }, ["lost"])
    }

    func testAMeetingHasItsOwnWordButIsStoredAsBefore() {
        XCTAssertEqual(PlannerKind.appointment.label, "Meeting")
        XCTAssertEqual(PlannerKind.appointment.rawValue, "appointment", "the rules validate this word")
    }
}

/// Tomorrow's class row: each homework on its own line, tests as blocks.
final class TomorrowClassItemsTests: XCTestCase {

    private func item(_ id: String, _ kind: PlannerKind) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: "2026-10-16", classBlock: "A", createdAt: Date(timeIntervalSince1970: 0))
    }

    func testHomeworkGetsALineEachAndTestsStayBlocks() {
        let split = TomorrowClassItems.split([item("exam", .test), item("memorize", .homework), item("read", .homework)], legacyNote: "")
        XCTAssertEqual(split.homework.map { $0.id }, ["memorize", "read"])
        XCTAssertEqual(split.tests.map { $0.id }, ["exam"])
    }

    func testAnOldStyleNoteKeepsTheLineSoHomeworkStaysABlock() {
        let split = TomorrowClassItems.split([item("memorize", .homework), item("exam", .test)], legacyNote: "do p. 40")
        XCTAssertTrue(split.homework.isEmpty)
        XCTAssertEqual(split.tests.map { $0.id }, ["memorize", "exam"])
    }

    func testEveryItemIsInExactlyOnePlace() {
        let all = [item("t", .test), item("h1", .homework), item("h2", .homework), item("s", .sports)]
        let split = TomorrowClassItems.split(all, legacyNote: "")
        XCTAssertEqual((split.homework + split.tests).map { $0.id }.sorted(), ["h1", "h2", "s", "t"])
    }

    func testTheRowIsTallEnoughForItsLines() {
        XCTAssertEqual(TomorrowClassItems.split([], legacyNote: "").rowHeight, 100, "nothing added: as before")
        XCTAssertEqual(TomorrowClassItems.split([item("t", .test)], legacyNote: "").rowHeight, 132, "tests only: as before")
        let one = TomorrowClassItems.split([item("h", .homework)], legacyNote: "").rowHeight
        let two = TomorrowClassItems.split([item("h", .homework), item("h2", .homework)], legacyNote: "").rowHeight
        XCTAssertEqual(two - one, 36, "each homework line adds one line")
        XCTAssertGreaterThan(one, 100)
        let withTest = TomorrowClassItems.split([item("h", .homework), item("t", .test)], legacyNote: "").rowHeight
        XCTAssertEqual(withTest - one, 36, "tests add one more equal line")
    }
}

/// The three-homework limit, tests that cannot be ticked, and tests that go away once they happen.
final class PlannerLimitsTests: XCTestCase {

    private func item(_ id: String, _ kind: PlannerKind, block: String? = "A", day: String = "2026-10-16", parent: String? = nil,
                      done: Bool = false) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: day, classBlock: block, completed: done,
                    createdAt: Date(timeIntervalSince1970: 0), parentId: parent)
    }

    func testAClassHoldsThreeHomeworkADayAndFinishedOnesStillCount() {
        let three = [item("a", .homework), item("b", .homework), item("c", .homework, done: true)]
        XCTAssertTrue(PlannerLimits.homeworkIsFull(block: "a", day: "2026-10-16", in: three))
        XCTAssertFalse(PlannerLimits.homeworkIsFull(block: "A", day: "2026-10-16", in: Array(three.prefix(2))))
    }

    func testOnlyTheSameClassAndDayAndOnlyHomeworkCount() {
        let items = [item("a", .homework), item("b", .homework, block: "C"), item("c", .homework, day: "2026-10-17"),
                     item("d", .test), item("e", .sports), item("s", .homework, parent: "d")]
        XCTAssertEqual(PlannerLimits.homeworkCount(block: "A", day: "2026-10-16", in: items), 1)
    }

    func testEditingOneOfTheThreeIsNotOverTheLimit() {
        let three = [item("a", .homework), item("b", .homework), item("c", .homework)]
        XCTAssertFalse(PlannerLimits.homeworkIsFull(block: "A", day: "2026-10-16", in: three, excluding: "a"))
        XCTAssertEqual(PlannerLimits.homeworkCount(block: "A", day: "2026-10-16", in: three, excluding: "a"), 2)
    }

    func testOnlyNewOrMovedHomeworkIsChecked() {
        let hw = item("a", .homework)
        XCTAssertTrue(PlannerLimits.needsHomeworkCheck(hw, replacing: nil))
        XCTAssertFalse(PlannerLimits.needsHomeworkCheck(hw, replacing: hw), "an unchanged edit")
        XCTAssertTrue(PlannerLimits.needsHomeworkCheck(hw, replacing: item("a", .homework, day: "2026-10-20")), "moved to this day")
        XCTAssertTrue(PlannerLimits.needsHomeworkCheck(hw, replacing: item("a", .test)), "a test turned into homework")
        XCTAssertFalse(PlannerLimits.needsHomeworkCheck(item("t", .test), replacing: nil))
        XCTAssertFalse(PlannerLimits.needsHomeworkCheck(item("n", .homework, block: nil), replacing: nil), "no class, no limit")
    }

    func testATestCannotBeTickedButItsStepsAndHomeworkCan() {
        XCTAssertFalse(PlannerLimits.canTick(item("t", .test)))
        XCTAssertTrue(PlannerLimits.canTick(item("s", .test, parent: "t")))
        XCTAssertTrue(PlannerLimits.canTick(item("h", .homework)))
        XCTAssertTrue(PlannerLimits.canTick(item("m", .appointment)))
    }

    func testAPastTestAndItsStepsAreGoneButTodaysStaysAndHomeworkIsUntouched() {
        let items = [item("old", .test, day: "2026-10-08"), item("oldStep", .test, day: "2026-10-07", parent: "old"),
                     item("today", .test, day: "2026-10-16"), item("late", .homework, day: "2026-10-08"),
                     item("soon", .test, day: "2026-10-20")]
        XCTAssertEqual(PlannerLimits.hidingPastTests(items, today: "2026-10-16").map { $0.id }, ["today", "late", "soon"])
    }

    func testOverdueUndoneItemsGoToPastWithTheirStepsAndNothingElseDoes() {
        let items = [item("late", .homework, day: "2026-10-10"), item("lateStep", .homework, day: "2026-10-09", parent: "late"),
                     item("doneLate", .homework, day: "2026-10-10", done: true), item("today", .homework, day: "2026-10-16"),
                     item("soon", .test, day: "2026-10-20"), item("game", .sports, day: "2026-10-12")]
        let split = PlannerLimits.splitPast(items, today: "2026-10-16")
        XCTAssertEqual(split.past.map { $0.id }, ["late", "lateStep", "game"])
        XCTAssertEqual(split.upcoming.map { $0.id }, ["today", "soon"], "a finished item from a past day is gone")
    }

    func testAPastTestIsInNeitherSection() {
        let items = [item("old", .test, day: "2026-10-08"), item("oldStep", .homework, day: "2026-10-07", parent: "old")]
        let split = PlannerLimits.splitPast(items, today: "2026-10-16")
        XCTAssertTrue(split.past.isEmpty)
        XCTAssertTrue(split.upcoming.isEmpty)
    }

    func testEveryVisibleItemIsInExactlyOneSection() {
        let items = [item("a", .homework, day: "2026-10-01"), item("b", .test, day: "2026-10-01"), item("c", .homework, day: "2026-10-30"),
                     item("d", .appointment, day: "2026-10-16"), item("e", .homework, day: "2026-10-01", done: true)]
        let split = PlannerLimits.splitPast(items, today: "2026-10-16")
        XCTAssertEqual((split.upcoming + split.past).map { $0.id }.sorted(), ["a", "c", "d"], "b is a past test, e is finished and past")
    }

    func testAFinishedItemStaysFadedUntilItsDayHasPassed() {
        let items = [item("todayDone", .homework, day: "2026-10-16", done: true), item("laterDone", .homework, day: "2026-10-20", done: true),
                     item("yesterdayDone", .homework, day: "2026-10-15", done: true)]
        let split = PlannerLimits.splitPast(items, today: "2026-10-16")
        XCTAssertEqual(split.upcoming.map { $0.id }, ["todayDone", "laterDone"])
        XCTAssertTrue(split.past.isEmpty)
    }
}

