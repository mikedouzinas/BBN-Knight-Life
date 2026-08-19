//
//  FirestoreParsingTests.swift
//  BBNDailyTests
//
//  HQ-627. Everything the app reads from Firestore used to be force-cast, so a single bad
//  field in a document nobody remembers editing was a launch crash for every student, with
//  nothing in the app to say why.
//
//  These tests feed the parser exactly the shapes that used to crash it. They assert on
//  behaviour (a bad row is skipped, a good row survives), not on wording, so a later rewrite
//  cannot make them pass vacuously.
//
//  FALSIFICATION: each safety test names, above it, what was reverted to make it fail and
//  what it printed. A test that has never failed is a claim, not a check.
//

import XCTest
@testable import BBNDaily

final class FirestoreParsingTests: XCTestCase {

    private var vc: AuthVC!

    override func setUpWithError() throws {
        vc = AuthVC()
    }

    override func tearDownWithError() throws {
        vc = nil
    }

    // MARK: - convertToEvent

    func testAWellFormedBlockParses() {
        let event = vc.convertToEvent(scheduleBlock: [
            "type": "block", "block": "a", "name": "A",
            "startTime": "8:15 am", "endTime": "9:00 am",
        ])

        XCTAssertEqual(event?.type, "block")
        XCTAssertEqual(event?.name, "A")
        XCTAssertEqual(event?.startTime, "8:15 am")
    }

    /// FALSIFIED 2026-08-19: restored `Event(type: scheduleBlock["type"]! as! String)`. The
    /// test did not merely fail, it CRASHED the test runner with
    ///   Fatal error: Unexpectedly found nil while unwrapping an Optional value
    /// which is exactly what a student's phone did on launch.
    func testABlockWithNoTypeIsSkippedRatherThanCrashing() {
        XCTAssertNil(vc.convertToEvent(scheduleBlock: ["block": "a", "name": "A"]))
    }

    /// FALSIFIED 2026-08-19: restored `ev.name = (scheduleBlock["name"] as! String)`, which
    /// crashed the runner with `Could not cast value of type 'NSNull'`.
    func testABlockMissingATimeIsSkipped() {
        XCTAssertNil(vc.convertToEvent(scheduleBlock: [
            "type": "block", "block": "a", "name": "A", "startTime": "8:15 am",
        ]), "a block with no end time is not a block")
    }

    func testALunchNeedsBothTimes() {
        XCTAssertNotNil(vc.convertToEvent(scheduleBlock: [
            "type": "lunch", "startTime": "11:25 am", "endTime": "11:55 am",
        ]))
        XCTAssertNil(vc.convertToEvent(scheduleBlock: ["type": "lunch", "startTime": "11:25 am"]))
    }

    /// A `specific` block with no `contents` was `as! [[String: Any]]`, so an empty one crashed.
    func testASpecificBlockWithNoContentsIsEmptyNotFatal() {
        let event = vc.convertToEvent(scheduleBlock: [
            "type": "specific", "filter": ["L1"], "matchMode": "any",
        ])

        XCTAssertEqual(event?.type, "specific")
        XCTAssertEqual(event?.contents?.count, 0)
    }

    func testASpecificBlockDropsOnlyItsBadChildren() {
        let event = vc.convertToEvent(scheduleBlock: [
            "type": "specific",
            "filter": ["L2"],
            "contents": [
                ["type": "block", "block": "c", "name": "C1",
                 "startTime": "11:25 am", "endTime": "12:10 pm"],
                ["type": "block", "block": "c"],  // no name, no times
            ],
        ])

        XCTAssertEqual(event?.contents?.count, 1, "the good child survives, the bad one goes")
        XCTAssertEqual(event?.contents?.first?.name, "C1")
    }

    func testDeeplyNestedContentsStillParse() {
        let event = vc.convertToEvent(scheduleBlock: [
            "type": "specific",
            "filter": ["9"],
            "contents": [[
                "type": "specific",
                "filter": ["L1"],
                "contents": [[
                    "type": "block", "block": "g", "name": "G2",
                    "startTime": "12:00 pm", "endTime": "12:45 pm",
                ]],
            ]],
        ])

        XCTAssertEqual(event?.contents?.first?.contents?.first?.name, "G2")
    }

    // MARK: - the shapes that came from real production documents

    /// The exact shape `schedules/special` holds for a no-school day, which is 10 of the 90
    /// days currently published.
    func testTheProductionNoSchoolShapeParses() {
        let event = vc.convertToEvent(scheduleBlock: [
            "type": "block", "block": "other", "name": "Assembly/Special Programming",
            "startTime": "9:55 am", "endTime": "10:30 am",
        ])
        XCTAssertEqual(event?.block, "other")
    }

    /// Firestore hands back NSNull for an explicitly null field, which is not the same as an
    /// absent key and is what `as!` chokes on hardest.
    func testAnExplicitlyNullFieldIsTreatedAsMissing() {
        XCTAssertNil(vc.convertToEvent(scheduleBlock: [
            "type": "block", "block": NSNull(), "name": "A",
            "startTime": "8:15 am", "endTime": "9:00 am",
        ]))
    }

    func testAWrongTypedFieldIsTreatedAsMissing() {
        XCTAssertNil(vc.convertToEvent(scheduleBlock: [
            "type": "block", "block": "a", "name": 42,
            "startTime": "8:15 am", "endTime": "9:00 am",
        ]), "a number where a name belongs is not a name")
    }
}
