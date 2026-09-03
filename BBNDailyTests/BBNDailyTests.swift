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
