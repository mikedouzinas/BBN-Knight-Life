//
//  TasksListingTests.swift
//  BBNDailyTests
//
//  HQ-2188. Tomorrow's Classes listed a homework row for any block the student had marked
//  Free, because "has a ~" was the only test and a Free block is stored like any class. These
//  pin the decision the Tasks list makes for one block, so it cannot drift from
//  ClassIdentity.isFree, the app's one definition of free.
//

import XCTest
@testable import BBNDaily

final class TasksListingTests: XCTestCase {

    func testARealClassIsListedBySubject() {
        XCTAssertEqual(WorkVC.listedSubject(forAssignment: "Precalculus~Ms. Lieberman~285~A"), "Precalculus")
    }

    /// The canonical form a scan writes, and the older hand-entered form with a placeholder
    /// teacher and room (what showed up as "Free NA" in Settings).
    func testAFreeBlockIsNotListed() {
        XCTAssertNil(WorkVC.listedSubject(forAssignment: "Free~~~D"))
        XCTAssertNil(WorkVC.listedSubject(forAssignment: "Free~NA~NA~G"))
    }

    /// Every wording ClassIdentity treats as free, so a block set by hand to "Study Hall" or
    /// left as the sheet's "Unscheduled" behaves like "Free".
    func testEveryWordingForFreeIsNotListed() {
        for wording in ["Free", "free", "Unscheduled", "Study Hall", "Free Period", "Open"] {
            XCTAssertNil(WorkVC.listedSubject(forAssignment: "\(wording)~~~F"), "\(wording) should not be listed")
        }
    }

    /// A course whose NAME contains a free-ish word is a course (ClassIdentityTests pins the
    /// same thing for isFree itself; this is the Tasks path).
    func testACourseThatLooksFreeIsStillListed() {
        for subject in ["Free Speech in America", "Freedom and Justice"] {
            XCTAssertEqual(WorkVC.listedSubject(forAssignment: "\(subject)~Mr. Turnbull~283~E"), subject)
        }
    }

    func testABlockWithNothingSetIsNotListed() {
        XCTAssertNil(WorkVC.listedSubject(forAssignment: ""))
        XCTAssertNil(WorkVC.listedSubject(forAssignment: "A Block"))
    }
}
