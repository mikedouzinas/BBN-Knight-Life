//
//  PlannerItemTests.swift
//  BBNDailyTests
//
//  HQ-2180. The pure half of the planner: how an item reads from and writes to a Firestore
//  dictionary, which days and times count as real, and which items are refused. Mirrors
//  validPlannerItem in firebase/firestore.rules, which the emulator tests exercise from the
//  server side.
//
//  PlannerStore itself (the Firestore calls) is not covered here: it needs a Firestore to talk to.
//

import XCTest
import FirebaseFirestore
@testable import BBNDaily

final class PlannerItemTests: XCTestCase {

    private func item(_ mutate: (inout PlannerItem) -> Void = { _ in }) -> PlannerItem {
        var value = PlannerItem(id: "item1", kind: .test, title: "Chemistry unit 4", dueDate: "2026-10-20",
                                createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        mutate(&value)
        return value
    }

    // MARK: - Reading and writing

    func testAnItemSurvivesAWriteAndARead() {
        let original = item {
            $0.dueTime = "15:30"; $0.classBlock = "C"; $0.notes = "bring calculator"
            $0.parentId = "parent1"; $0.isBig = true; $0.completed = true
        }
        let read = PlannerItem(id: original.id, data: original.firestoreData)
        XCTAssertEqual(read, original)
    }

    func testOptionalFieldsAreLeftOutRatherThanWrittenEmpty() {
        let data = item().firestoreData
        for key in ["dueTime", "classBlock", "notes", "parentId", "isBig"] {
            XCTAssertNil(data[key], "\(key) should be absent, not empty: the rules reject an empty optional")
        }
    }

    func testEmptyNotesAreLeftOut() {
        XCTAssertNil(item { $0.notes = "" }.firestoreData["notes"])
    }

    func testAnUnknownKindIsDroppedNotCrashedOn() {
        var data = item().firestoreData
        data["kind"] = "party"   // a kind a newer build might add
        XCTAssertNil(PlannerItem(id: "x", data: data))
    }

    func testEveryKindRoundTrips() {
        for kind in PlannerKind.allCases {
            let original = item { $0.kind = kind }
            XCTAssertEqual(PlannerItem(id: original.id, data: original.firestoreData)?.kind, kind)
        }
    }

    func testADocumentMissingRequiredFieldsIsDropped() {
        XCTAssertNil(PlannerItem(id: "x", data: [:]))
        XCTAssertNil(PlannerItem(id: "x", data: ["kind": "test", "title": "No date"]))
        XCTAssertNil(PlannerItem(id: "x", data: ["kind": "test", "dueDate": "2026-10-20", "title": ""]))
    }

    func testADocumentWithAnImpossibleDateIsDropped() {
        var data = item().firestoreData
        data["dueDate"] = "2026-02-30"
        XCTAssertNil(PlannerItem(id: "x", data: data))
    }

    func testAMissingCreatedAtDoesNotDropTheItem() {
        // A write still in flight reads back without its server timestamp.
        var data = item().firestoreData
        data.removeValue(forKey: "createdAt")
        XCTAssertNotNil(PlannerItem(id: "x", data: data))
    }

    // MARK: - Days and times

    func testDayStringIsASCIIISOForm() {
        let day = PlannerItem.dayString(from: Date(timeIntervalSince1970: 1_790_000_000))
        XCTAssertNotNil(day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression), day)
    }

    func testDayStringUsesTheGivenTimeZone() {
        // 2026-10-21 03:00 UTC is still the 20th in Los Angeles and already the 21st in UTC.
        let instant = Date(timeIntervalSince1970: 1_792_551_600)
        XCTAssertEqual(PlannerItem.dayString(from: instant, timeZone: TimeZone(identifier: "UTC")!), "2026-10-21")
        XCTAssertEqual(PlannerItem.dayString(from: instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!), "2026-10-20")
    }

    func testRealDaysParseAndImpossibleOnesDoNot() {
        XCTAssertNotNil(PlannerItem.date(fromDay: "2026-10-20"))
        XCTAssertNotNil(PlannerItem.date(fromDay: "2028-02-29"))   // leap day
        for bad in ["2026-02-30", "2026-02-29", "2026-13-01", "2026-00-10", "2026-1-5", "10/20/2026", "", "tomorrow"] {
            XCTAssertNil(PlannerItem.date(fromDay: bad), "\(bad) is not a day")
        }
    }

    func testDayAndStringRoundTrip() {
        let zone = TimeZone(identifier: "America/New_York")!
        let date = PlannerItem.date(fromDay: "2026-11-01", timeZone: zone)!   // the DST change day
        XCTAssertEqual(PlannerItem.dayString(from: date, timeZone: zone), "2026-11-01")
    }

    func testTimes() {
        for good in ["00:00", "09:05", "15:30", "23:59"] { XCTAssertTrue(PlannerItem.isValidTime(good), good) }
        for bad in ["24:00", "12:60", "3pm", "9:05", "09:5", "", "12:30:00", "ab:cd"] {
            XCTAssertFalse(PlannerItem.isValidTime(bad), bad)
        }
    }

    // MARK: - Validation

    func testAGoodItemHasNoError() { XCTAssertNil(item().validationError()) }

    func testTitleRules() {
        XCTAssertEqual(item { $0.title = "" }.validationError(), .emptyTitle)
        XCTAssertEqual(item { $0.title = "   \n " }.validationError(), .emptyTitle)
        XCTAssertNil(item { $0.title = String(repeating: "x", count: FieldLimits.plannerTitle) }.validationError())
        XCTAssertEqual(item { $0.title = String(repeating: "x", count: FieldLimits.plannerTitle + 1) }.validationError(),
                       .titleTooLong(limit: FieldLimits.plannerTitle))
    }

    func testNotesRules() {
        XCTAssertNil(item { $0.notes = String(repeating: "x", count: FieldLimits.plannerNotes) }.validationError())
        XCTAssertEqual(item { $0.notes = String(repeating: "x", count: FieldLimits.plannerNotes + 1) }.validationError(),
                       .notesTooLong(limit: FieldLimits.plannerNotes))
    }

    func testDateTimeAndBlockRules() {
        XCTAssertEqual(item { $0.dueDate = "2026-02-30" }.validationError(), .badDate)
        XCTAssertEqual(item { $0.dueTime = "25:00" }.validationError(), .badTime)
        XCTAssertEqual(item { $0.classBlock = "H" }.validationError(), .badClassBlock)
        XCTAssertEqual(item { $0.classBlock = "c" }.validationError(), .badClassBlock, "blocks are stored upper-case")
        for block in ["A", "B", "C", "D", "E", "F", "G"] {
            XCTAssertNil(item { $0.classBlock = block }.validationError())
        }
    }

    func testParentRules() {
        XCTAssertNil(item { $0.parentId = "someoneElse" }.validationError())
        XCTAssertEqual(item { $0.parentId = "" }.validationError(), .badParent)
        XCTAssertEqual(item { $0.parentId = "item1" }.validationError(), .badParent, "an item cannot be its own parent")
        XCTAssertEqual(item { $0.parentId = String(repeating: "p", count: PlannerItem.parentIdLimit + 1) }.validationError(), .badParent)
    }

    func testEveryErrorHasAMessageForTheStudent() {
        let errors: [PlannerValidationError] = [.emptyTitle, .titleTooLong(limit: 80), .badDate, .badTime,
                                                .badClassBlock, .notesTooLong(limit: 300), .badParent, .missingID]
        for error in errors { XCTAssertFalse(error.message.isEmpty) }
    }
}
