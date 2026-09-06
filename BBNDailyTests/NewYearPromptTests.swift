//
//  NewYearPromptTests.swift
//  BBNDailyTests
//
//  The new-year prompt is the only thing that tells a student their classes need setting up.
//  If it does not fire, the student opens the app to seven blank blocks with nothing explaining
//  why, and nothing offering to fix it. There is no second channel.
//
//  HQ-954: the guard trusted `classesSetForTermStart` alone. `startNewYearSetup` writes that
//  field on the success of the CLEAR, before anything new is saved, so a student who backed out
//  of the scanner or never opened Settings was marked set up with zero classes and was never
//  asked again. Two real students were found in that state on 2026-09-06, two days before the
//  term started, out of the handful who had reached the prompt at all. On the first morning of
//  school every student meets that prompt.
//
//  The decision was three booleans buried in a closure inside a Firestore callback inside a view
//  controller, where no test could reach it. It is `isSetUpForTerm` now, and these are its tests.
//

import XCTest
@testable import BBNDaily

final class NewYearPromptTests: XCTestCase {

    private let term = "2026/9/8"

    /// The whole point of the fix. This is the exact shape of the two stranded students.
    func testFlaggedButNoClassesIsNotSetUp() {
        XCTAssertFalse(
            AuthVC.isSetUpForTerm(recordedFor: term, termStart: term, hasAnyClass: false),
            "A student marked set up with no classes must still be prompted - this is HQ-954, "
                + "and treating them as set up costs them the entire term."
        )
    }

    /// The only combination that may suppress the prompt.
    func testFlaggedWithClassesIsSetUp() {
        XCTAssertTrue(
            AuthVC.isSetUpForTerm(recordedFor: term, termStart: term, hasAnyClass: true)
        )
    }

    /// Everyone on the first morning: classes cleared for the new year, never asked yet.
    func testNeverRecordedIsNotSetUp() {
        XCTAssertFalse(AuthVC.isSetUpForTerm(recordedFor: nil, termStart: term, hasAnyClass: false))
        XCTAssertFalse(AuthVC.isSetUpForTerm(recordedFor: "", termStart: term, hasAnyClass: false))
    }

    /// A student holding LAST year's classes is the original HQ-620 case and must be prompted.
    /// Having classes is not on its own evidence of being set up for the term running now.
    func testLastYearsFlagWithClassesIsNotSetUp() {
        XCTAssertFalse(
            AuthVC.isSetUpForTerm(recordedFor: "2025/9/9", termStart: term, hasAnyClass: true),
            "Classes from a previous term must not suppress this term's prompt."
        )
    }

    /// A student who has classes but was never flagged: still prompted, and correctly so. The
    /// prompt's own wording branches on hasAnyClass, so it reads as "clear last year's" for them.
    func testClassesButNoFlagIsNotSetUp() {
        XCTAssertFalse(AuthVC.isSetUpForTerm(recordedFor: nil, termStart: term, hasAnyClass: true))
    }

    /// Guards against the fix being "simplified" back into the bug. If either input stops
    /// mattering, one of these fails.
    func testBothInputsAreLoadBearing() {
        let setUp = AuthVC.isSetUpForTerm(recordedFor: term, termStart: term, hasAnyClass: true)

        XCTAssertNotEqual(
            setUp,
            AuthVC.isSetUpForTerm(recordedFor: term, termStart: term, hasAnyClass: false),
            "hasAnyClass stopped affecting the result - the HQ-954 bug is back."
        )
        XCTAssertNotEqual(
            setUp,
            AuthVC.isSetUpForTerm(recordedFor: "2025/9/9", termStart: term, hasAnyClass: true),
            "recordedFor stopped affecting the result - the prompt would now fire forever."
        )
    }
}
