//
//  BBNDailyTests.swift
//  BBNDailyTests
//
//  Created by Mike Veson on 9/6/21.
//
//  The Xcode template's `testExample` and `testPerformanceExample` lived here from 2021 to
//  2026 and asserted nothing. They are gone.
//
//  Worth a note rather than a silent deletion, because they are the exact failure this
//  project keeps meeting in other costumes: a check that examines nothing is worse than no
//  check at all, since it occupies the slot and reports success. For five years this target
//  could be run and would pass, which is indistinguishable from a target with real coverage
//  until somebody looks.
//
//  Real tests live in:
//    ResolveDayTests         - what day it is, which decides everything a student sees
//    FirestoreParsingTests   - surviving a malformed document instead of crashing on launch
//
//  CI runs the whole target and fails when the executed count is zero, so an empty suite
//  cannot pass quietly again.
//

import XCTest
import UIKit
@testable import BBNDaily

/// The one thing about the schedule-scan review screen that no other check in this repository
/// can see.
///
/// On 2026-09-03 that screen had shipped to a device with every value on its right-hand side
/// missing: the lunch wave, the grade, and every teacher and room. The cause was one line,
/// `tableView.register(UITableViewCell.self, forCellReuseIdentifier:)`, which produces cells in
/// `.default` style - and a `.default` cell's `detailTextLabel` is nil, so each
/// `cell.detailTextLabel?.text = value` did nothing at all.
///
/// It got past everything. The project compiled, 42 tests passed, the expected strings were all
/// present in the binary, and the app installed and ran. Nothing was wrong with the data or the
/// logic; the labels being written to did not exist. It was found by Mike reading the screen and
/// saying the lunch row would not tell him which wave he had.
///
/// A string in a binary proves the text was compiled in. It cannot prove there is a label to put
/// it in. This test can.
/// HQ-922: which weekdays a scanned class actually meets.
///
/// `nil` means the sheet did not say and every day stays on. It must never be read as an empty
/// week, which would hide the class from the calendar on all five days.
final class ScannedClassMeetingDaysTests: XCTestCase {

    private func row(_ days: [String]?) -> ScannedClass {
        ScannedClass(block: "c", subject: "Ceramics", teacher: "Ms. Lee", room: "200", days: days)
    }

    func testNotReadMeansEveryDayMeets() {
        let scanned = row(nil)
        for day in ScannedClass.weekdays {
            XCTAssertTrue(scanned.days.map { $0.contains(day) } ?? true, "\(day) should stay on when days were not read")
        }
    }

    func testOnlyTheNamedDaysMeet() {
        let scanned = row(["tuesday", "thursday"])
        XCTAssertEqual(
            ScannedClass.weekdays.map { day in scanned.days.map { $0.contains(day) } ?? true },
            [false, true, false, true, false])
    }

    /// The summary is what makes a misread visible on the review screen, so a partial week has to
    /// render and a full week has to stay quiet.
    func testAPartialWeekReadsInWeekdayOrder() {
        XCTAssertEqual(row(["friday", "monday"]).meetingDaysSummary, "Mon, Fri")
    }

    func testAFullWeekSaysNothing() {
        XCTAssertEqual(row(ScannedClass.weekdays).meetingDaysSummary, "")
        XCTAssertEqual(row(nil).meetingDaysSummary, "")
    }
}

/// Joining a class that already exists must still be able to fill in days nobody has set.
///
/// Mike, testing on a fresh account 2026-09-03: all seven of his blocks joined existing
/// documents, so none of them got weekday flags and every class showed all week. 326 class
/// documents survived the reset, so most students on Tuesday JOIN rather than create.
final class ExistingClassMeetingDaysTests: XCTestCase {

    func testAClassWithNoFlagsAtAllCountsAsUnset() {
        XCTAssertTrue(ScheduleScanVC.meetsEveryWeekday([:]))
        XCTAssertTrue(ScheduleScanVC.meetsEveryWeekday(nil))
    }

    func testFiveExplicitTruesCountAsUnset() {
        var data: [String: Any] = [:]
        for day in ScannedClass.weekdays { data[day] = true }
        XCTAssertTrue(ScheduleScanVC.meetsEveryWeekday(data))
    }

    /// The guard. One `false` anywhere means somebody decided about this class, and a scan must
    /// not overwrite that.
    func testASingleFalseMeansSomebodyDecided() {
        for off in ScannedClass.weekdays {
            var data: [String: Any] = [:]
            for day in ScannedClass.weekdays { data[day] = (day != off) }
            XCTAssertFalse(
                ScheduleScanVC.meetsEveryWeekday(data),
                "a class with \(off) turned off must be left alone")
        }
    }

    /// A partially-written document: some flags present and true, the rest missing. Still unset,
    /// because a missing flag reads as true everywhere else in the app.
    func testAPartiallyWrittenDocumentIsStillUnset() {
        XCTAssertTrue(ScheduleScanVC.meetsEveryWeekday(["monday": true, "friday": true]))
        XCTAssertFalse(ScheduleScanVC.meetsEveryWeekday(["monday": true, "friday": false]))
    }
}

final class ScanReviewCellTests: XCTestCase {

    func testReviewCellCanShowARightHandValue() {
        let cell = ScheduleScanVC.makeReviewCell()
        XCTAssertNotNil(
            cell.detailTextLabel,
            """
            The review list's cell style has no detailTextLabel, so every right-hand value on \
            the scan review screen will be assigned to nil and silently not render - the lunch \
            wave, the grade, and every teacher and room. Use .value1 or .subtitle, not .default, \
            and do not go back to register(UITableViewCell.self, ...).
            """)
    }

    /// The UIKit fact the test above depends on, asserted rather than assumed.
    ///
    /// Without this, a future UIKit release that gave `.default` cells a detail label would make
    /// the test above pass for a reason unrelated to what it is guarding, and the guard would
    /// quietly stop guarding. This is the falsification half: it proves the assertion above can
    /// actually fail.
    func testDefaultStyleIsTheTrapThisGuards() {
        XCTAssertNil(
            UITableViewCell(style: .default, reuseIdentifier: nil).detailTextLabel,
            "A .default cell gained a detailTextLabel, so testReviewCellCanShowARightHandValue no longer proves anything.")
        XCTAssertNotNil(
            UITableViewCell(style: .value1, reuseIdentifier: nil).detailTextLabel,
            ".value1 lost its detailTextLabel, so the review screen needs a different style.")
    }
}

/// Does the scan screen lay out on the SMALLEST iPhone anyone still runs this on?
///
/// Mike, 2026-09-03: "I worry the popup to verify/edit classes won't fit on some screens so make
/// sure it does and ALL our features are made to fit all iPhone screens fine. I can't test that
/// easily." Neither can a person with one phone, which is exactly why it belongs in a test.
///
/// This does not prove the screen looks good. It proves the two things that silently go wrong when
/// a layout written on a large phone meets a small one: constraints that cannot all be satisfied,
/// and a fixed-size element that leaves the actual content no room. The photo preview used to be a
/// hard 160pt, which is better than a quarter of an SE's screen.
final class ScanScreenLayoutTests: XCTestCase {

    /// iPhone SE (3rd gen) in points - the smallest screen this app supports.
    private let smallest = CGRect(x: 0, y: 0, width: 375, height: 667)
    /// iPhone 17 Pro Max, near the top of the range.
    private let largest = CGRect(x: 0, y: 0, width: 440, height: 956)

    private func laidOut(in frame: CGRect) -> ScheduleScanVC {
        let vc = ScheduleScanVC()
        vc.view.frame = frame
        vc.view.layoutIfNeeded()
        return vc
    }

    func testLaysOutOnTheSmallestPhoneWithoutConflicts() {
        let vc = laidOut(in: smallest)
        XCTAssertFalse(vc.view.hasAmbiguousLayout, "The scan screen's layout is ambiguous on an iPhone SE.")
    }

    func testLaysOutOnTheLargestPhoneWithoutConflicts() {
        let vc = laidOut(in: largest)
        XCTAssertFalse(vc.view.hasAmbiguousLayout, "The scan screen's layout is ambiguous on a large iPhone.")
    }

    /// The proportional height and the cap are a deliberate pair: `.defaultHigh` for the 22% and
    /// required for the 170pt cap. Two REQUIRED constraints there would be unsatisfiable on any
    /// phone taller than about 773pt, which is most of them.
    func testPhotoPreviewNeverEatsTheScreen() {
        for (name, frame) in [("SE", smallest), ("Pro Max", largest)] {
            let vc = laidOut(in: frame)
            let preview = vc.view.subviews.compactMap { $0 as? UIImageView }.first
            guard let height = preview?.frame.height else {
                XCTFail("No photo preview found on \(name)"); continue
            }
            XCTAssertGreaterThan(height, 0, "The photo preview collapsed to nothing on \(name).")
            XCTAssertLessThanOrEqual(
                height, 175,
                "The photo preview is \(height)pt on \(name); the cap is 170 and it is stealing room from the rows being confirmed.")
            XCTAssertLessThan(
                height, frame.height * 0.3,
                "The photo preview takes \(Int(height / frame.height * 100))% of the screen on \(name).")
        }
    }

    /// The review list has to be the biggest thing on the screen, on every phone. It is what the
    /// student is actually reading.
    func testTheListGetsMostOfTheScreen() {
        for (name, frame) in [("SE", smallest), ("Pro Max", largest)] {
            let vc = laidOut(in: frame)
            let table = vc.view.subviews.compactMap { $0 as? UITableView }.first
            guard let table = table else { XCTFail("No review table found on \(name)"); continue }
            XCTAssertGreaterThan(
                table.frame.height, frame.height * 0.5,
                "The review list only gets \(Int(table.frame.height / frame.height * 100))% of the screen on \(name).")
        }
    }
}
