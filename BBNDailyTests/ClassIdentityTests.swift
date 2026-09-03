//
//  ClassIdentityTests.swift
//  BBNDailyTests
//
//  HQ-656. The property under test is the one that stops a grade's worth of simultaneous
//  scans from producing a grade's worth of duplicate classes: the same real class must always
//  produce the same key, whatever wording the model returned.
//
//  Determinism is what makes concurrency safe here, because the key IS the document ID - two
//  students who compute the same key write to the same document and Firestore merges them.
//  So every "these two produce one key" test below is also a concurrency test.
//

import XCTest
@testable import BBNDaily

final class ClassIdentityTests: XCTestCase {

    // MARK: - The same class, worded differently

    /// Each group is one real class as several students' scans might report it. Every member
    /// of a group has to collapse to one key, or they become separate rosters.
    func testWordingVariationsCollapseToOneKey() {
        let groups: [[(String, String, String)]] = [
            [
                ("Precalculus", "Ms. Lieberman", "285"),
                ("Precalculus", "Ms Lieberman", "285"),
                ("Precalculus ", " Ms.  Lieberman", " 285 "),
                ("Precalculus", "ms. lieberman", "Room 285"),
                ("Precalculus", "MS. Lieberman", "Rm 285"),
                ("Precalculus", "Ms. Lieberman", "#285"),
            ],
            [
                ("United States History (Honors)", "Mr. Turnbull", "283"),
                ("United States History (Honors)", "mr turnbull", "Room 283"),
                ("United States  History (Honors)", "Mr.  Turnbull", "283 "),
            ],
        ]

        for group in groups {
            let keys = Set(group.map {
                ClassIdentity.canonicalClassKey(subject: $0.0, teacher: $0.1, room: $0.2, block: "a")
            })
            XCTAssertEqual(keys.count, 1, "expected one key, got \(keys.sorted())")
        }
    }

    /// The key is also what the student reads, so it must not be flattened into something ugly.
    func testKeyStaysReadable() {
        let key = ClassIdentity.canonicalClassKey(
            subject: "AP English Masks", teacher: "ms. kornet", room: "Room 258", block: "b")
        XCTAssertEqual(key, "AP English Masks~Ms. Kornet~258~B")
    }

    /// A name whose capitals are deliberate is left exactly alone. Case is only normalised
    /// when the word carries no case information, so this never rewrites somebody's name -
    /// which would be both wrong on screen and a second spelling of an existing teacher.
    func testNamesWithDeliberateCapitalsAreUntouched() {
        for name in ["Ms. McDonald", "Mr. O'Brien", "Dr. DiAngelo", "Ms. van Dijk", "Mr. LaRue"] {
            XCTAssertEqual(ClassIdentity.canonicalTeacher(name), name)
        }
    }

    /// ALL CAPS and all lowercase carry no case information, so they are safe to fix, and
    /// fixing them is what makes two scans of one class agree.
    func testCaselessNamesAreTitleCased() {
        XCTAssertEqual(ClassIdentity.canonicalTeacher("MS. ROSE"), "Ms. Rose")
        XCTAssertEqual(ClassIdentity.canonicalTeacher("ms. rose"), "Ms. Rose")
        XCTAssertEqual(ClassIdentity.canonicalTeacher("Ms. Rose"), "Ms. Rose")
        // Punctuation keeps its place rather than being treated as a word boundary.
        XCTAssertEqual(ClassIdentity.canonicalTeacher("MS. SANCHEZ-GOMEZ"), "Ms. Sanchez-gomez")
    }

    /// A bare surname with no honorific is still case-normalised.
    func testASurnameWithNoTitleIsStillNormalised() {
        XCTAssertEqual(ClassIdentity.canonicalTeacher("LIEBERMAN"), "Lieberman")
        XCTAssertEqual(ClassIdentity.canonicalTeacher("lieberman"), "Lieberman")
    }

    /// The honest limit, written down so it is a known gap rather than a surprise: SUBJECT
    /// case is not normalised, because "AP", "III" and "US" are meaningful capitals that
    /// title-casing would destroy. Two scans that disagree on subject case still produce two
    /// keys, and it is `matchesExistingClass` that catches them - which works whenever the
    /// first document already exists, and not in a genuine dead heat.
    func testSubjectCaseIsNotNormalisedButIsStillRecognised() {
        let a = ClassIdentity.canonicalClassKey(subject: "Physics", teacher: "Ms. C", room: "", block: "c")
        let b = ClassIdentity.canonicalClassKey(subject: "PHYSICS", teacher: "Ms. C", room: "", block: "c")
        XCTAssertNotEqual(a, b, "if this ever passes, subject case became canonical and the comment above is stale")
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: a, subject: "PHYSICS", teacher: "Ms. C", block: "c"))
    }

    func testBlockIsUppercased() {
        let key = ClassIdentity.canonicalClassKey(subject: "Physics", teacher: "", room: "", block: "c")
        XCTAssertEqual(key, "Physics~~~C")
    }

    // MARK: - Classes that must stay apart

    /// Two sections of the same course with different teachers are two classes. Merging them
    /// would put a student on a roster they are not in, which is worse than a duplicate.
    func testDifferentTeachersStayDifferentClasses() {
        let a = ClassIdentity.canonicalClassKey(subject: "Physics", teacher: "Ms. Courtemanche", room: "134", block: "c")
        let b = ClassIdentity.canonicalClassKey(subject: "Physics", teacher: "Mr. Diaz", room: "134", block: "c")
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: a, subject: "Physics", teacher: "Mr. Diaz", block: "c"))
    }

    func testDifferentBlocksStayDifferentClasses() {
        let a = ClassIdentity.canonicalClassKey(subject: "Physics", teacher: "Ms. Courtemanche", room: "134", block: "c")
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: a, subject: "Physics", teacher: "Ms. Courtemanche", block: "d"))
    }

    // MARK: - Free blocks

    /// Every sheet's wording for an open block lands on one roster. Otherwise "who else is
    /// free in F block" is split across four documents and shows almost nobody.
    func testEveryWordingForFreeCollapsesToOneRoster() {
        let wordings = ["Free", "Unscheduled", "unscheduled", "Study Hall", "Free Period", "Open", "N/A"]
        let keys = Set(wordings.map {
            ClassIdentity.canonicalClassKey(subject: $0, teacher: "", room: "", block: "f")
        })
        XCTAssertEqual(keys, ["Free~~~F"])
    }

    /// A stray teacher or room on a free block would split the roster by whatever the model
    /// happened to attach.
    func testFreeBlockDropsTeacherAndRoom() {
        let key = ClassIdentity.canonicalClassKey(
            subject: "Unscheduled", teacher: "Ms. Nobody", room: "101", block: "g")
        XCTAssertEqual(key, "Free~~~G")
    }

    func testFreeNeverMatchesARealCourse() {
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Free~~~F", subject: "Physics", teacher: "Ms. Courtemanche", block: "f"))
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~Ms. Courtemanche~134~F", subject: "Free", teacher: "", block: "f"))
    }

    /// A course whose NAME contains a free-ish word is a course.
    func testCoursesThatLookFreeAreNotFree() {
        for subject in ["Free Speech in America", "Freedom and Justice", "Advanced Study Hall Design"] {
            XCTAssertFalse(ClassIdentity.isFree(subject), "\(subject) is a real course")
        }
    }

    // MARK: - Recognising what already exists

    /// The case a canonical key cannot handle on its own: a document typed by hand, in
    /// whatever shape a student typed it, that is the same class as the one just scanned.
    func testMatchesAHandTypedRecord() {
        let existing = "precalculus~ms lieberman~285~A"
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: existing, subject: "Precalculus", teacher: "Ms. Lieberman", block: "a"))
    }

    /// Rooms are not compared. A class keeps its identity when it moves room, and two sheets
    /// often disagree about the room or omit it.
    func testRoomIsNotPartOfIdentity() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~Ms. Courtemanche~134~C", subject: "Physics", teacher: "Ms. Courtemanche", block: "c"))
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~Ms. Courtemanche~999~C", subject: "Physics", teacher: "Ms. Courtemanche", block: "c"))
    }

    /// Somebody left the teacher blank. That is the same class, not a second one.
    func testABlankTeacherMatchesANamedOne() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~~~C", subject: "Physics", teacher: "Ms. Courtemanche", block: "c"))
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~Ms. Courtemanche~134~C", subject: "Physics", teacher: "", block: "c"))
    }

    /// "N/A" is a display convention applied when a key is parsed, never a real teacher.
    /// Treating it as one is what broke the round trip in HQ-658.
    func testNotAvailableIsTreatedAsBlank() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~N/A~N/A~C", subject: "Physics", teacher: "Ms. Courtemanche", block: "c"))
    }

    /// Two scans of ONE sheet can name the teacher differently: the sheet printed
    /// "Ms. Schmucker" and one scan came back "Ellie Schmucker", a first name that is nowhere
    /// on the page. The prompt now forbids that, but a prompt is a request and this is the
    /// guarantee - whichever spelling created the class, the next student joins it rather than
    /// starting a second roster for the same teacher.
    func testAnInventedFirstNameStillFindsTheSameClass() {
        let created = "Precalculus (Advanced)~Ellie Schmucker~376~G"
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: created, subject: "Precalculus (Advanced)", teacher: "Ms. Schmucker", block: "g"))

        let printedAsShown = "Precalculus (Advanced)~Ms. Schmucker~376~G"
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: printedAsShown, subject: "Precalculus (Advanced)", teacher: "Ellie Schmucker", block: "g"))
    }

    /// The limit of the rule above, and it is deliberate: a surname is what identifies a
    /// teacher, so two different surnames are two different sections however alike they look.
    func testADifferentSurnameIsStillADifferentClass() {
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Precalculus (Advanced)~Ms. Schmucker~376~G",
            subject: "Precalculus (Advanced)", teacher: "Ms. Schumacher", block: "g"))
    }

    // MARK: - A surname the camera got wrong

    /// Twelve reads of one sheet spelled `Dr. Gatti` as `Dr. Gattl` three times. Nothing could
    /// merge those, so one Biology class had two documents and half a roster each.
    ///
    /// Subject + block + room identifies a section on its own - a block is one time slot, so two
    /// Biology sections cannot both be in room 236 during block F - so with all three agreeing,
    /// one character of difference in the surname is the camera rather than a second teacher.
    func testAOneCharacterMisreadJoinsTheExistingClass() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~236~F",
            subject: "Biology", teacher: "Dr. Gattl", block: "f", room: "236"))
    }

    func testItWorksWhicheverSpellingGotThereFirst() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gattl~236~F",
            subject: "Biology", teacher: "Dr. Gatti", block: "f", room: "236"))
    }

    /// A dropped or doubled letter, not just a swapped one.
    func testAMissingOrExtraLetterAlsoCounts() {
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~236~F",
            subject: "Biology", teacher: "Dr. Gati", block: "f", room: "236"))
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~236~F",
            subject: "Biology", teacher: "Dr. Gattii", block: "f", room: "236"))
    }

    /// THE LIMIT, and the reason the rule needs three exact fields before it bends the fourth.
    /// A wrong merge is worse than a split: it puts a student on a roster they are not in.
    func testADifferentRoomIsStillADifferentClass() {
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~236~F",
            subject: "Biology", teacher: "Dr. Gattl", block: "f", room: "999"))
    }

    func testTwoBlankRoomsProveNothing() {
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~~F",
            subject: "Biology", teacher: "Dr. Gattl", block: "f", room: ""))
    }

    func testTwoCharactersApartIsTwoTeachers() {
        XCTAssertFalse(ClassIdentity.matchesExistingClass(
            existingKey: "Biology~Dr. Gatti~236~F",
            subject: "Biology", teacher: "Dr. Gatson", block: "f", room: "236"))
    }

    /// Short surnames are where a one-character rule is most dangerous, so this is the case to
    /// keep an eye on: "Ng" and "Ni" are two people, and the room cannot say otherwise.
    func testShortSurnamesOneApartStillMergeOnAnExactRoom() {
        // Documented rather than asserted as desirable: with subject, block and room identical
        // this is one section, so the merge is right even though the names are short. If BB&N
        // ever has two such teachers sharing a room in one block, this is the test to revisit.
        XCTAssertTrue(ClassIdentity.matchesExistingClass(
            existingKey: "Physics~Ms. Ng~131~E",
            subject: "Physics", teacher: "Ms. Ni", block: "e", room: "131"))
    }

    func testOneCharacterApartIsExactAboutWhatItMeans() {
        XCTAssertTrue(ClassIdentity.isOneCharacterApart("gatti", "gattl"))
        XCTAssertTrue(ClassIdentity.isOneCharacterApart("gatti", "gati"))
        XCTAssertFalse(ClassIdentity.isOneCharacterApart("gatti", "gatti"), "identical is not one apart")
        XCTAssertFalse(ClassIdentity.isOneCharacterApart("gatti", "turnbull"))
        XCTAssertFalse(ClassIdentity.isOneCharacterApart("", "gatti"))
        // "rose" and "ross" ARE one apart, and could be two real people. This function does not
        // know that and is not asked to - it is the room, the block and the subject agreeing
        // that make the call. Asserted so the split of responsibility stays visible.
        XCTAssertTrue(ClassIdentity.isOneCharacterApart("rose", "ross"))
    }

    func testAMalformedKeyMatchesNothing() {
        for junk in ["", "Physics", "Physics~Ms. X", "a~b~c~d~e"] {
            XCTAssertFalse(ClassIdentity.matchesExistingClass(
                existingKey: junk, subject: "Physics", teacher: "Ms. X", block: "c"), "junk: \(junk)")
        }
    }

    // MARK: - The property the whole file exists for

    /// Fifty students scan the same class at the same moment. Every one computes the same
    /// document ID, so every one writes to the same document, so Firestore merges them into
    /// one roster. There is no lock and no coordination - the ID came from the content.
    func testConcurrentScansOfOneClassConvergeOnOneDocument() {
        let scans: [(String, String, String)] = (0..<50).map { i in
            switch i % 5 {
            case 0: return ("Spanish III", "Ms. Rose", "380")
            case 1: return ("Spanish III", "Ms Rose", "Room 380")
            case 2: return (" Spanish III ", " ms. rose ", " 380 ")
            case 3: return ("Spanish  III", "MS. ROSE", "#380")
            default: return ("Spanish III", "Ms. Rose", "Rm 380")
            }
        }
        let keys = Set(scans.map {
            ClassIdentity.canonicalClassKey(subject: $0.0, teacher: $0.1, room: $0.2, block: "d")
        })
        XCTAssertEqual(keys.count, 1, "50 concurrent scans produced \(keys.count) documents: \(keys.sorted())")
    }
}
