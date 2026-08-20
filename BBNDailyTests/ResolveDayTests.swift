//
//  ResolveDayTests.swift
//  BBNDailyTests
//
//  resolveDay decides what every student sees and what every notification fires for. Until
//  HQ-640 it had no tests at all, which is how the app came to show a full seven-block
//  Wednesday in the middle of August 2026.
//
//  The tests that matter most here are the ones about NOT knowing something. A missing term,
//  an unparseable term, a reversed one: each has to leave the app behaving as it did before,
//  because "the read failed" must never render to 582 students as "there is no school today".
//

import XCTest
@testable import BBNDaily

final class ResolveDayTests: XCTestCase {

    /// resolveDay lives on a UIViewController extension, so a bare one stands in for any screen.
    private var vc: UIViewController!

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.timeZone = TimeZone.current
        guard let parsed = formatter.date(from: string) else {
            XCTFail("test wrote an unparseable date: \(string)")
            return Date()
        }
        return parsed
    }

    override func setUpWithError() throws {
        vc = UIViewController()
        // Global state, reset per test. resolveDay reads all three.
        LoginVC.specialDays = [:]
        LoginVC.breaks = []
        LoginVC.term = nil
    }

    override func tearDownWithError() throws {
        LoginVC.specialDays = [:]
        LoginVC.breaks = []
        LoginVC.term = nil
        vc = nil
    }

    // MARK: - The safety property: not knowing must not mean "no school"

    /// The single most important assertion in this file. With no term on file the app must
    /// behave exactly as it did before terms existed.
    ///
    /// FALSIFIED 2026-08-19: changed resolveDay's guard from `if let term = LoginVC.term`
    /// to `if LoginVC.term == nil || ...`, i.e. fail closed. This failed with
    ///   ResolveDayTests.swift:58: error: XCTAssertTrue failed - With no term on file the
    ///   app must fall through to the weekly pattern...
    /// and it was the only one of the ten that failed, which is the point: nothing else in
    /// this file notices that particular mistake.
    func testMissingTermFallsBackToTheRegularSchedule() {
        LoginVC.term = nil

        // A Wednesday in the middle of summer, which is the exact date that started HQ-640.
        let resolved = vc.resolveDay(date: date("2026/8/19"))

        XCTAssertTrue(resolved.hasClasses,
                      "With no term on file the app must fall through to the weekly pattern. "
                      + "Treating an unknown term as 'no school' would tell the whole school "
                      + "there is no class the first time a Firestore read fails.")
    }

    func testUnparseableTermFallsBackToTheRegularSchedule() {
        LoginVC.term = Term(startDate: "not a date", endDate: "also not a date", reason: "Summer break")

        let resolved = vc.resolveDay(date: date("2026/8/19"))

        XCTAssertTrue(resolved.hasClasses, "A malformed term is a broken read, not a closed school.")
    }

    func testReversedTermFallsBackToTheRegularSchedule() {
        // End before start. Somebody typed the fields in the wrong boxes.
        LoginVC.term = Term(startDate: "2027/6/8", endDate: "2026/9/8", reason: "Summer break")

        let resolved = vc.resolveDay(date: date("2026/10/14"))

        XCTAssertTrue(resolved.hasClasses, "A reversed term is a typo, not a year with no school.")
    }

    // MARK: - The rule itself

    func testAWeekdayOutsideTheTermIsNoSchool() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")

        let resolved = vc.resolveDay(date: date("2026/8/19"))

        XCTAssertFalse(resolved.hasClasses)
        XCTAssertEqual(resolved.emptyMessage, "No Class - Summer break")
        if case .outsideTerm = resolved.kind {} else {
            XCTFail("expected .outsideTerm, got \(resolved.kind)")
        }
    }

    func testAWeekdayInsideTheTermKeepsItsRegularSchedule() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")

        // A Wednesday in October, nothing published against it.
        let resolved = vc.resolveDay(date: date("2026/10/14"))

        XCTAssertTrue(resolved.hasClasses)
        XCTAssertNil(resolved.emptyMessage)
    }

    /// Both ends inclusive: the first and last day of classes are school days.
    func testTheFirstAndLastDayOfTermAreInsideIt() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")

        XCTAssertTrue(vc.resolveDay(date: date("2026/9/8")).hasClasses, "first day of classes")
        XCTAssertTrue(vc.resolveDay(date: date("2027/6/8")).hasClasses, "last day of classes")
        XCTAssertFalse(vc.resolveDay(date: date("2027/6/9")).hasClasses, "the day after the last day")
    }

    // MARK: - What setNotifications actually asks

    /// `setNotifications` walks the next 14 days and fires only where `hasClasses` is true.
    /// So "does the app notify during summer" is answerable without a device, a push
    /// certificate, or waiting until 8am: it is a question about fourteen ResolvedDays.
    ///
    /// This is the test for HQ-634. The bug was that notifications fired straight through
    /// summer, and the only way it surfaced was somebody noticing alarms on their own phone in
    /// August. That is not a test strategy.
    ///
    /// FALSIFIED 2026-08-19, and it took two goes, which is the useful part. Disabling the
    /// outside-term rule alone did NOT fail it: the summer break RANGE still covers August, so
    /// two independent mechanisms have to be removed before a student gets an alarm. Removing
    /// both printed the exact days that would have fired:
    ///     XCTAssertEqual failed: ("["2026/8/19", "2026/8/20", "2026/8/21", "2026/8/24",
    ///     "2026/8/25", "2026/8/26", "2026/8/27", "2026/8/28", "2026/8/31", "2026/9/1"]")
    ///     is not equal to ("[]")
    /// Ten August mornings. That is the bug, named.
    func testNoDayInTheNextTwoWeeksHasClassesDuringSummer() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        LoginVC.breaks = [Break(reason: "Summer break", startDate: "2026/6/15", endDate: "2026/9/7")]

        // Mid-August, the window that produced the seven-block Wednesday.
        let start = date("2026/8/19")
        var withClasses: [String] = []
        for offset in 0...13 {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            if vc.resolveDay(date: day).hasClasses {
                withClasses.append(describe(day))
            }
        }

        XCTAssertEqual(withClasses, [],
                       "setNotifications fires on exactly these days, so any entry here is an "
                       + "alarm during summer break")
    }

    /// The other half, and the one that would catch an over-correction: once term starts, the
    /// same walk MUST produce school days. A change that silenced summer by silencing
    /// everything would pass the test above and fail this one.
    func testTheSameWalkDoesFindClassesOnceTermStarts() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        LoginVC.breaks = [Break(reason: "Summer break", startDate: "2026/6/15", endDate: "2026/9/7")]

        let start = date("2026/9/8")
        var withClasses = 0
        for offset in 0...13 {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            if vc.resolveDay(date: day).hasClasses { withClasses += 1 }
        }

        // Two weeks from the first day of school: ten weekdays, none of them published as
        // special in this fixture.
        XCTAssertEqual(withClasses, 10, "two school weeks should carry ten days of classes")
    }

    /// Thanksgiving: the window straddles a break, so some days notify and some do not. A
    /// resolver that got precedence wrong would return all fourteen or none.
    func testAWindowStraddlingABreakNotifiesOnlyTheSchoolDays() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        LoginVC.breaks = [Break(reason: "Thanksgiving break", startDate: "2026/11/25", endDate: "2026/11/29")]

        let start = date("2026/11/23")   // the Monday before
        var withClasses: [String] = []
        for offset in 0...13 {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            if vc.resolveDay(date: day).hasClasses { withClasses.append(describe(day)) }
        }

        XCTAssertFalse(withClasses.contains("2026/11/25"), "first day of the break")
        XCTAssertFalse(withClasses.contains("2026/11/29"), "last day of the break")
        XCTAssertTrue(withClasses.contains("2026/11/23"), "the Monday before is a school day")
        XCTAssertTrue(withClasses.contains("2026/11/30"), "classes resume the Monday after")
    }

    private func describe(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d"
        return f.string(from: d)
    }

    // MARK: - Precedence, which is the part a future change is most likely to break

    func testAPublishedDayWinsOverTheTerm() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        // Graduation, published for a date outside the term.
        LoginVC.specialDays["2027/6/12"] = Day(type: "noschool", blocks: nil,
                                               reason: "Commencement", imageUrl: nil)

        let resolved = vc.resolveDay(date: date("2027/6/12"))

        XCTAssertEqual(resolved.emptyMessage, "No Class - Commencement",
                       "An explicitly published day is somebody's decision and outranks an inference.")
    }

    func testABreakWinsOverTheRegularSchedule() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        LoginVC.breaks = [Break(reason: "Thanksgiving break", startDate: "2026/11/25", endDate: "2026/11/29")]

        let resolved = vc.resolveDay(date: date("2026/11/25"))

        XCTAssertFalse(resolved.hasClasses)
        XCTAssertEqual(resolved.emptyMessage, "No Class - Thanksgiving break")
    }

    func testWeekendsAreWeekendsEvenInsideTheTerm() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")

        let resolved = vc.resolveDay(date: date("2026/10/17")) // a Saturday

        XCTAssertFalse(resolved.hasClasses)
        XCTAssertEqual(resolved.emptyMessage, "No Class - Enjoy your weekend")
    }

    /// A reversed break range used to be a runtime trap: CalendarVC built `(start...end)`,
    /// which crashes when start is later than end. One console typo took the app down for
    /// everyone. isDateInBreak compares the bounds instead, so it is simply not a match.
    func testAReversedBreakRangeDoesNotCrash() {
        LoginVC.term = Term(startDate: "2026/9/8", endDate: "2027/6/8", reason: "Summer break")
        LoginVC.breaks = [Break(reason: "Typo break", startDate: "2026/11/29", endDate: "2026/11/25")]

        let resolved = vc.resolveDay(date: date("2026/11/26"))

        XCTAssertTrue(resolved.hasClasses, "a reversed range matches nothing, and crashes nothing")
    }
}
