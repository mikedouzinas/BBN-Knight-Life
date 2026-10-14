//
//  PlannerRemindersTests.swift
//  BBNDailyTests
//
//  HQ-2185. When a reminder fires, which ones are chosen, and the one thing that must not go wrong:
//  planner reminders and class reminders sharing iOS's 64-notification cap, neither starving the
//  other.
//

import XCTest
@testable import BBNDaily

final class PlannerRemindersTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let ny = TimeZone(identifier: "America/New_York")!
    /// 2026-10-04 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_115_200)

    private func item(_ id: String, _ due: String, _ reminder: PlannerReminder = .evening, kind: PlannerKind = .test,
                      completed: Bool = false, remindAt: Date? = nil, block: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: id, dueDate: due, classBlock: block, completed: completed,
                    reminder: reminder, remindAt: remindAt)
    }

    private func local(_ day: String, _ hour: Int, _ minute: Int = 0, _ zone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: PlannerItem.date(fromDay: day, timeZone: zone)!)!
    }

    // MARK: - When

    func testEveningBeforeIsSevenPMTheDayBefore() {
        XCTAssertEqual(PlannerReminders.fireDate(for: item("a", "2026-10-20"), now: now, timeZone: ny), local("2026-10-19", 19, 0, ny))
    }

    func testMorningOfIsSevenAMThatDay() {
        XCTAssertEqual(PlannerReminders.fireDate(for: item("a", "2026-10-20", .morning), now: now, timeZone: ny), local("2026-10-20", 7, 0, ny))
    }

    func testEveningBeforeCrossesAMonthAndAYearBoundary() {
        XCTAssertEqual(PlannerReminders.fireDate(for: item("a", "2026-11-01"), now: now, timeZone: ny), local("2026-10-31", 19, 0, ny))
        XCTAssertEqual(PlannerReminders.fireDate(for: item("a", "2027-01-01"), now: now, timeZone: ny), local("2026-12-31", 19, 0, ny))
    }

    /// 2026-11-01 is the fall-back day in the US. The evening before a due date of Nov 2 is Nov 1 at
    /// 7 PM, which is 25 hours after Nov 1 midnight, not 24: adding a fixed number of hours lands
    /// an hour off.
    func testEveningBeforeIsStillSevenPMAcrossADaylightSavingChange() {
        let fire = PlannerReminders.fireDate(for: item("a", "2026-11-02"), now: now, timeZone: ny)
        XCTAssertEqual(fire, local("2026-11-01", 19, 0, ny))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ny
        XCTAssertEqual(cal.component(.hour, from: fire!), 19)
        // And the spring-forward day: due Mar 9 2027 (DST began Mar 14 2027; use that day's eve).
        let spring = PlannerReminders.fireDate(for: item("b", "2027-03-15"), now: now, timeZone: ny)
        XCTAssertEqual(cal.component(.hour, from: spring!), 19)
    }

    func testTheSameItemRemindsAtTheStudentsLocalTimeInEachZone() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let a = PlannerReminders.fireDate(for: item("a", "2026-10-20"), now: now, timeZone: ny)!
        let b = PlannerReminders.fireDate(for: item("a", "2026-10-20"), now: now, timeZone: la)!
        XCTAssertEqual(b.timeIntervalSince(a), 3 * 3600, accuracy: 1, "7 PM in LA is three hours after 7 PM in New York")
    }

    func testCustomUsesTheExactMoment() {
        let moment = now.addingTimeInterval(5 * 86_400)
        XCTAssertEqual(PlannerReminders.fireDate(for: item("a", "2026-10-20", .custom, remindAt: moment), now: now), moment)
        XCTAssertNil(PlannerReminders.fireDate(for: item("a", "2026-10-20", .custom, remindAt: nil), now: now), "custom with no time has nothing to fire")
    }

    func testNoReminderMeansNoDate() {
        XCTAssertNil(PlannerReminders.fireDate(for: item("a", "2026-10-20", .none), now: now))
    }

    func testAMomentThatHasPassedIsNotScheduled() {
        // Added at 8 PM for tomorrow: this evening's 7 PM is gone.
        let late = local("2026-10-04", 20, 0, utc)
        XCTAssertNil(PlannerReminders.fireDate(for: item("a", "2026-10-05"), now: late, timeZone: utc))
        XCTAssertNotNil(PlannerReminders.fireDate(for: item("a", "2026-10-05", .morning), now: late, timeZone: utc), "but tomorrow morning is still ahead")
    }

    func testAMomentLessThanThirtySecondsAwayIsNotScheduled() {
        XCTAssertNil(PlannerReminders.fireDate(for: item("a", "2026-10-20", .custom, remindAt: now.addingTimeInterval(10)), now: now))
        XCTAssertNotNil(PlannerReminders.fireDate(for: item("a", "2026-10-20", .custom, remindAt: now.addingTimeInterval(60)), now: now))
    }

    // MARK: - What

    func testPlanSkipsFinishedItemsKeyDatesAndItemsWithNothingToSay() {
        let items = [
            item("open", "2026-10-20"),
            item("done", "2026-10-20", completed: true),
            item("none", "2026-10-20", .none),
            item("past", "2026-10-01"),
            PlannerItem(id: PlannerItem.keyDateIDPrefix + "x", kind: .test, title: "Midterms", dueDate: "2026-10-20", reminder: .evening),
        ]
        XCTAssertEqual(PlannerReminders.plan(items: items, now: now, timeZone: utc).map { $0.itemID }, ["open"])
    }

    func testPlanIsSoonestFirstWhateverOrderItemsArriveIn() {
        let items = [item("late", "2026-12-01"), item("soon", "2026-10-10"), item("mid", "2026-11-01")]
        XCTAssertEqual(PlannerReminders.plan(items: items, now: now, timeZone: utc).map { $0.itemID }, ["soon", "mid", "late"])
        XCTAssertEqual(PlannerReminders.plan(items: items.reversed(), now: now, timeZone: utc).map { $0.itemID }, ["soon", "mid", "late"])
    }

    func testPlanIsCappedAtTwentyAndKeepsTheSoonest() {
        let items = (1...30).map { item("i\(String(format: "%02d", $0))", "2026-11-\(String(format: "%02d", min($0, 28)))") }
        let plan = PlannerReminders.plan(items: items, now: now, timeZone: utc)
        XCTAssertEqual(plan.count, PlannerReminders.maxPending)
        XCTAssertEqual(plan.first?.itemID, "i01")
        XCTAssertTrue(plan.map { $0.fireDate } == plan.map { $0.fireDate }.sorted())
    }

    func testIdentifiersAreDeterministicAndRecognisable() {
        let request = PlannerReminders.plan(items: [item("abc", "2026-10-20")], now: now, timeZone: utc)[0]
        XCTAssertEqual(request.identifier, "planner:abc:0")
        XCTAssertTrue(PlannerReminders.isPlannerIdentifier(request.identifier))
        XCTAssertFalse(PlannerReminders.isPlannerIdentifier("8F2A1C3E-0B4D-4E5F-9A6B-7C8D9E0F1A2B"), "a class reminder uses a UUID")
        XCTAssertEqual(PlannerReminders.plan(items: [item("abc", "2026-10-20")], now: now, timeZone: utc)[0].identifier, request.identifier,
                       "planning twice gives the same id, so the second replaces the first")
    }

    func testTheBodySaysWhatAndWhenRightForTheMomentItFires() {
        let en = Locale(identifier: "en_US")
        _ = en
        let evening = PlannerReminders.plan(items: [item("a", "2026-10-20", .evening, block: "C")], now: now, timeZone: utc)[0]
        XCTAssertEqual(evening.body, "Test · due tomorrow · Block C")
        let morning = PlannerReminders.plan(items: [item("a", "2026-10-20", .morning, kind: .homework)], now: now, timeZone: utc)[0]
        XCTAssertEqual(morning.body, "Homework · due today")
        XCTAssertEqual(evening.title, "a")
    }

    // MARK: - The cap

    func testClassBudgetIsWhatThePlannerLeaves() {
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: 0), 64)
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: 5), 59)
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: 20), 44)
    }

    func testClassBudgetNeverFallsBelow44EvenIfAskedForMore() {
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: 50), 44, "the planner can take at most its 20")
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: -3), 64)
    }

    /// The test the ticket asked for: fill the budget from BOTH sides and check neither starves the
    /// other, and that together they never pass what iOS will hold.
    func testTheBudgetIsFilledFromBothSidesAndNeitherStarvesTheOther() {
        // A fortnight of school: 9 days of 8 reminders = 72, far more than 64 on its own.
        let heavyClasses = Array(repeating: 8, count: 9)
        // A planner with 30 reminders waiting: more than its 20.
        let items = (1...30).map { item("i\($0)", "2026-11-\(String(format: "%02d", min($0, 28)))") }
        let planner = PlannerReminders.plan(items: items, now: now, timeZone: utc)

        let classDays = NotificationBudget.fit(dayBlockCounts: heavyClasses, budget: PlannerReminders.classBudget(plannerCount: planner.count))
        let classReminders = zip(classDays, heavyClasses).filter { $0.0 }.map { $0.1 }.reduce(0, +)

        XCTAssertEqual(planner.count, 20, "classes could not eat the planner's slice")
        XCTAssertGreaterThanOrEqual(classReminders, 40, "and the planner could not eat the classes' (44 available, whole days of 8 fit 40)")
        XCTAssertEqual(classReminders, 40)
        XCTAssertLessThanOrEqual(classReminders + planner.count, PlannerReminders.systemLimit)
    }

    func testAnEmptyPlannerGivesClassesTheWholeBudget() {
        let days = NotificationBudget.fit(dayBlockCounts: Array(repeating: 8, count: 9), budget: PlannerReminders.classBudget(plannerCount: 0))
        XCTAssertEqual(days.filter { $0 }.count, 8, "64 / 8 = 8 whole days, exactly what it did before the planner existed")
    }

    func testAFewPlannerRemindersCostClassesOnlyWhatTheyUse() {
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [8, 8, 8], budget: PlannerReminders.classBudget(plannerCount: 2)).filter { $0 }.count, 3)
    }

    // MARK: - The class budget loop, unchanged by being extracted

    func testFitStopsAtTheFirstDayThatWouldOverflowAndStaysStopped() {
        // 30 + 30 fit in 64; the third (10) would be 70, so it stops; the fourth (1) fits arithmetically
        // but must NOT be scheduled, or a day goes missing from the middle.
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [30, 30, 10, 1], budget: 64), [true, true, false, false])
    }

    func testFitIgnoresDaysWithNoReminders() {
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [0, 8, 0, 8], budget: 64), [false, true, false, true])
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [8, 0, 70, 0, 1], budget: 64), [true, false, false, false, false],
                       "a no-school day between does not reset the latch")
    }

    func testFitWithNothingToFit() {
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [], budget: 64), [])
        XCTAssertEqual(NotificationBudget.fit(dayBlockCounts: [5], budget: 0), [false])
    }
}

final class PlannerReminderCacheTests: XCTestCase {

    private func item(_ id: String, _ due: String, _ reminder: PlannerReminder = .evening, completed: Bool = false) -> PlannerItem {
        PlannerItem(id: id, kind: .test, title: id, dueDate: due, completed: completed, reminder: reminder)
    }

    func testAReadReplacesItsOwnWindowAndKeepsTheRest() {
        var cache = PlannerReminderCache(items: [item("oct", "2026-10-10"), item("dec", "2026-12-10")])
        XCTAssertTrue(cache.apply(items: [item("oct2", "2026-10-12")], window: ("2026-10-01", "2026-10-31")))
        XCTAssertEqual(Set(cache.items.map { $0.id }), ["oct2", "dec"], "oct was absent from the read so it was deleted; dec is outside the window so is untouched")
    }

    func testAnItemDeletedElsewhereDropsOutOnTheNextRead() {
        var cache = PlannerReminderCache(items: [item("gone", "2026-10-10")])
        cache.apply(items: [], window: ("2026-10-01", "2026-10-31"))
        XCTAssertTrue(cache.items.isEmpty)
    }

    func testApplyReportsWhetherAnythingChanged() {
        let same = item("a", "2026-10-10")
        var cache = PlannerReminderCache(items: [same])
        XCTAssertFalse(cache.apply(items: [same], window: ("2026-10-01", "2026-10-31")), "same data: no reschedule needed")
        XCTAssertTrue(cache.apply(items: [item("a", "2026-10-11")], window: ("2026-10-01", "2026-10-31")))
    }

    /// Notes, createdAt and the like change no reminder, so they must not trigger a reschedule.
    func testChangesThatDoNotAffectAReminderDoNotCountAsChanges() {
        var cache = PlannerReminderCache(items: [item("a", "2026-10-10")])
        var edited = item("a", "2026-10-10")
        edited.notes = "bring calculator"
        edited.createdAt = Date(timeIntervalSince1970: 5)
        XCTAssertFalse(cache.apply(items: [edited], window: ("2026-10-01", "2026-10-31")))
        XCTAssertEqual(cache.items.first?.notes, "bring calculator", "the fresh copy is still kept")
    }

    func testEveryFieldAReminderDependsOnDoesCountAsAChange() {
        func changes(_ edit: (inout PlannerItem) -> Void) -> Bool {
            var cache = PlannerReminderCache(items: [item("a", "2026-10-10")])
            var edited = item("a", "2026-10-10"); edit(&edited)
            return cache.apply(items: [edited], window: ("2026-10-01", "2026-10-31"))
        }
        XCTAssertTrue(changes { $0.title = "other" })
        XCTAssertTrue(changes { $0.kind = .homework })
        XCTAssertTrue(changes { $0.dueDate = "2026-10-11" })
        XCTAssertTrue(changes { $0.classBlock = "C" })
        XCTAssertTrue(changes { $0.completed = true })
        XCTAssertTrue(changes { $0.reminder = .morning })
        XCTAssertTrue(changes { $0.reminder = .custom; $0.remindAt = Date(timeIntervalSince1970: 9) })
    }

    func testARestoredCacheDoesNotLookChangedWhenTheSameItemsComeBackFromTheServer() {
        let original = item("a", "2026-10-10")
        var restored = PlannerReminderCache(decoding: PlannerReminderCache(items: [original]).encoded())
        XCTAssertFalse(restored.apply(items: [original], window: ("2026-10-01", "2026-10-31")),
                       "restored from disk has no createdAt; that must not read as a change")
    }

    func testAnItemOutsideTheWindowIsNotAddedByARead() {
        var cache = PlannerReminderCache()
        cache.apply(items: [item("far", "2027-06-01")], window: ("2026-10-01", "2026-10-31"))
        XCTAssertTrue(cache.items.isEmpty)
    }

    func testUpsertAndRemove() {
        var cache = PlannerReminderCache()
        let a = item("a", "2026-10-10")
        XCTAssertTrue(cache.upsert(a))
        XCTAssertFalse(cache.upsert(a))
        XCTAssertTrue(cache.remove(id: "a"))
        XCTAssertFalse(cache.remove(id: "a"))
    }

    func testPersistenceKeepsOnlyWhatAReminderCouldStillComeFrom() throws {
        let cache = PlannerReminderCache(items: [
            item("keep", "2026-10-10"), item("done", "2026-10-10", completed: true), item("none", "2026-10-10", .none),
        ])
        let restored = PlannerReminderCache(decoding: cache.encoded())
        XCTAssertEqual(restored.items.map { $0.id }, ["keep"])
    }

    func testPersistenceRoundTripsEveryFieldAReminderNeeds() {
        let moment = Date(timeIntervalSince1970: 1_792_000_000)
        let original = PlannerItem(id: "x", kind: .appointment, title: "Orthodontist", dueDate: "2026-10-20", classBlock: "C",
                                   reminder: .custom, remindAt: moment)
        let restored = PlannerReminderCache(decoding: PlannerReminderCache(items: [original]).encoded()).items.first
        XCTAssertEqual(restored?.title, "Orthodontist")
        XCTAssertEqual(restored?.kind, .appointment)
        XCTAssertEqual(restored?.dueDate, "2026-10-20")
        XCTAssertEqual(restored?.classBlock, "C")
        XCTAssertEqual(restored?.reminder, .custom)
        XCTAssertEqual(restored?.remindAt, moment)
    }

    func testGarbageOrNothingDecodesToAnEmptyCacheNotACrash() {
        XCTAssertTrue(PlannerReminderCache(decoding: nil).items.isEmpty)
        XCTAssertTrue(PlannerReminderCache(decoding: Data("not json".utf8)).items.isEmpty)
        XCTAssertTrue(PlannerReminderCache(decoding: Data("[{\"id\":1}]".utf8)).items.isEmpty)
    }

    func testAnUnknownKindOrReminderFromANewerBuildIsSkippedNotFatal() {
        let json = #"[{"id":"a","kind":"party","title":"t","dueDate":"2026-10-10","reminder":"evening"},{"id":"b","kind":"test","title":"t","dueDate":"2026-10-10","reminder":"hourly"},{"id":"c","kind":"test","title":"t","dueDate":"2026-10-10","reminder":"evening"}]"#
        XCTAssertEqual(PlannerReminderCache(decoding: Data(json.utf8)).items.map { $0.id }, ["c"])
    }
}

final class PlannerReminderNoteTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let now = Date(timeIntervalSince1970: 1_791_115_200)   // 2026-10-04 12:00 UTC

    private func item(_ reminder: PlannerReminder, due: String = "2026-10-20", remindAt: Date? = nil) -> PlannerItem {
        PlannerItem(id: "x", kind: .test, title: "x", dueDate: due, reminder: reminder, remindAt: remindAt)
    }
    private func note(_ item: PlannerItem, _ permission: ReminderPermission = .granted, appOn: Bool = true) -> String? {
        PlannerReminders.note(for: item, now: now, permission: permission, appNotificationsOn: appOn, timeZone: utc)
    }

    func testNoNoteWhenThereIsNoReminderOrNothingIsWrong() {
        XCTAssertNil(note(item(.none), .denied, appOn: false), "no reminder chosen, so nothing to warn about")
        XCTAssertNil(note(item(.evening)))
    }

    func testAMomentThatHasPassedIsSaidOutLoud() {
        XCTAssertEqual(note(item(.evening, due: "2026-10-04")), "That moment has already passed, so there won't be a reminder.")
        XCTAssertEqual(note(item(.custom, remindAt: now.addingTimeInterval(-3600))), "That time has already passed, so there won't be a reminder.")
    }

    func testDeniedPermissionIsSaidOutLoud() {
        XCTAssertEqual(note(item(.evening), .denied), "Notifications are off for Knight Life in your iPhone's Settings, so this reminder won't show up.")
    }

    func testTheAppsOwnToggleIsSaidOutLoud() {
        XCTAssertEqual(note(item(.evening), .granted, appOn: false), "Notifications are turned off in Knight Life's settings, so this reminder won't show up.")
    }

    func testNotYetAskedIsNotAWarning() {
        XCTAssertNil(note(item(.evening), .unknown), "the editor asks when a reminder is chosen")
    }

    func testAPassedMomentIsReportedBeforeThePhoneSettings() {
        XCTAssertEqual(note(item(.evening, due: "2026-10-04"), .denied), "That moment has already passed, so there won't be a reminder.")
    }

    func testDefaultCustomTimeIsTheEveningBeforeOrAnHourFromNowIfThatIsGone() {
        let future = PlannerReminders.defaultCustomTime(forDueDay: "2026-10-20", now: now, timeZone: utc)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        XCTAssertEqual(cal.component(.hour, from: future), 19)
        XCTAssertEqual(PlannerItem.dayString(from: future, timeZone: utc), "2026-10-19")
        XCTAssertEqual(PlannerReminders.defaultCustomTime(forDueDay: "2026-10-04", now: now, timeZone: utc), now.addingTimeInterval(3600))
    }
}

final class PlannerLadderTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let ny = TimeZone(identifier: "America/New_York")!
    /// 2026-10-04 12:00 UTC (Sunday).
    private let now = Date(timeIntervalSince1970: 1_791_115_200)

    private func big(_ id: String = "t", due: String, rungs: Set<LadderRung> = Set(LadderRung.allCases),
                     completed: Bool = false, kind: PlannerKind = .test, block: String? = nil) -> PlannerItem {
        PlannerItem(id: id, kind: kind, title: "Chemistry test", dueDate: due, classBlock: block, completed: completed,
                    isBig: true, reminder: .none, rungs: rungs)
    }
    private func rungs(_ item: PlannerItem, now: Date? = nil, zone: TimeZone? = nil) -> [String] {
        PlannerReminders.ladderRequests(for: item, now: now ?? self.now, timeZone: zone ?? utc).map { $0.title }
    }
    private func local(_ day: String, _ hour: Int, _ zone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: PlannerItem.date(fromDay: day, timeZone: zone)!)!
    }

    // MARK: - The two cases the ticket names

    /// A test added 10 days out schedules all four rungs.
    func testATenDaysOutTestGetsAllFourRungs() {
        let requests = PlannerReminders.ladderRequests(for: big(due: "2026-10-14"), now: now, timeZone: utc)
        XCTAssertEqual(requests.count, 4)
        XCTAssertEqual(requests.map { $0.title }, ["Chemistry test in 1 week", "Chemistry test in 3 days", "Chemistry test tomorrow", "Chemistry test today"])
    }

    /// One added 2 days out schedules only the two that are still in the future.
    func testATwoDaysOutTestGetsOnlyTheTwoRungsStillAhead() {
        XCTAssertEqual(rungs(big(due: "2026-10-06")), ["Chemistry test tomorrow", "Chemistry test today"])
    }

    // MARK: - When each rung fires

    func testEachRungFiresOnItsOwnDayAtTheRightHour() {
        let r = PlannerReminders.ladderRequests(for: big(due: "2026-10-20"), now: now, timeZone: ny)
        XCTAssertEqual(r.map { $0.fireDate }, [local("2026-10-13", 19, ny), local("2026-10-17", 19, ny), local("2026-10-19", 19, ny), local("2026-10-20", 7, ny)])
    }

    func testARungIsSevenPMAcrossADaylightSavingChange() {
        // Due Nov 2 2026: "a week before" is Oct 26 and "the night before" is Nov 1 (the fall-back day).
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ny
        for rung in [LadderRung.week, .threeDays, .dayBefore] {
            let fire = PlannerReminders.fireDate(rung: rung, for: big(due: "2026-11-02"), now: now, timeZone: ny)!
            XCTAssertEqual(cal.component(.hour, from: fire), 19, "\(rung)")
        }
        XCTAssertEqual(PlannerReminders.fireDate(rung: .dayBefore, for: big(due: "2026-11-02"), now: now, timeZone: ny), local("2026-11-01", 19, ny))
    }

    func testRungsCrossAMonthAndYearBoundary() {
        XCTAssertEqual(PlannerReminders.fireDate(rung: .week, for: big(due: "2027-01-03"), now: now, timeZone: utc), local("2026-12-27", 19, utc))
        XCTAssertEqual(PlannerReminders.fireDate(rung: .dayBefore, for: big(due: "2026-11-01"), now: now, timeZone: utc), local("2026-10-31", 19, utc))
    }

    // MARK: - Skipping, never firing late

    func testADeadlineTodayGetsTheMorningRungOnlyIfThatHourIsStillAhead() {
        XCTAssertEqual(rungs(big(due: "2026-10-04"), now: local("2026-10-04", 5, utc)), ["Chemistry test today"], "5 AM: 7 AM is ahead")
        XCTAssertEqual(rungs(big(due: "2026-10-04"), now: local("2026-10-04", 8, utc)), [], "8 AM: it has gone")
    }

    func testAPastDeadlineGetsNothing() {
        XCTAssertEqual(rungs(big(due: "2026-09-30")), [])
    }

    func testARungLessThanThirtySecondsAwayIsSkipped() {
        let almost = local("2026-10-13", 19, utc).addingTimeInterval(-10)
        XCTAssertFalse(rungs(big(due: "2026-10-20"), now: almost).contains("Chemistry test in 1 week"))
    }

    // MARK: - Turning rungs off

    func testSwitchingARungOffRemovesJustThatRung() {
        let item = big(due: "2026-10-20", rungs: [.week, .dayBefore, .morningOf])
        XCTAssertEqual(rungs(item), ["Chemistry test in 1 week", "Chemistry test tomorrow", "Chemistry test today"])
    }

    func testAllRungsOffMeansNoReminders() {
        XCTAssertEqual(rungs(big(due: "2026-10-20", rungs: [])), [])
    }

    // MARK: - Completing, deleting, and replacing the single reminder

    func testACompletedBigItemLeavesNoRungs() {
        XCTAssertTrue(PlannerReminders.plan(items: [big(due: "2026-10-20", completed: true)], now: now, timeZone: utc).isEmpty)
    }

    func testABigItemsCountdownReplacesItsSingleReminderInsteadOfAddingToIt() {
        var both = big(due: "2026-10-20")
        both.reminder = .evening
        let plan = PlannerReminders.plan(items: [both], now: now, timeZone: utc)
        XCTAssertEqual(plan.count, 4, "four rungs, not four plus a fifth 'night before'")
        XCTAssertEqual(Set(plan.map { $0.identifier }).count, 4)
    }

    func testAnOrdinaryItemKeepsItsSingleReminder() {
        let plain = PlannerItem(id: "hw", kind: .homework, title: "Worksheet", dueDate: "2026-10-20", reminder: .evening)
        XCTAssertEqual(PlannerReminders.plan(items: [plain], now: now, timeZone: utc).map { $0.title }, ["Worksheet"])
    }

    func testRungIdentifiersAreDistinctStableAndRecognisable() {
        let ids = PlannerReminders.ladderRequests(for: big(due: "2026-10-20"), now: now, timeZone: utc).map { $0.identifier }
        XCTAssertEqual(ids, ["planner:t:1", "planner:t:2", "planner:t:3", "planner:t:4"])
        XCTAssertTrue(ids.allSatisfy { PlannerReminders.isPlannerIdentifier($0) })
    }

    // MARK: - It uses the one scheduler and its one budget

    func testRungsCountAgainstThePlannersTwentyAndNeverMore() {
        let items = (1...10).map { big("b\($0)", due: "2026-11-\(String(format: "%02d", $0 + 5))") }   // 10 big items x 4 rungs = 40
        let plan = PlannerReminders.plan(items: items, now: now, timeZone: utc)
        XCTAssertEqual(plan.count, PlannerReminders.maxPending)
        XCTAssertEqual(PlannerReminders.classBudget(plannerCount: plan.count), 44, "classes keep their 44")
        XCTAssertEqual(plan.map { $0.fireDate }, plan.map { $0.fireDate }.sorted(), "soonest first across every item's rungs")
    }

    func testRungsAndOrdinaryRemindersShareOneSoonestFirstOrder() {
        let plain = PlannerItem(id: "hw", kind: .homework, title: "Worksheet", dueDate: "2026-10-14", reminder: .evening)
        let plan = PlannerReminders.plan(items: [big(due: "2026-10-20"), plain], now: now, timeZone: utc)
        XCTAssertEqual(plan.map { $0.fireDate }, plan.map { $0.fireDate }.sorted())
        XCTAssertTrue(plan.contains { $0.itemID == "hw" })
        XCTAssertEqual(plan.filter { $0.itemID == "t" }.count, 4)
    }

    // MARK: - Wording

    func testTheTitleSaysWhatAndWhen() {
        XCTAssertEqual(PlannerReminders.ladderTitle("Chemistry test", rung: .threeDays), "Chemistry test in 3 days")
        XCTAssertEqual(PlannerReminders.ladderTitle("Essay", rung: .dayBefore), "Essay tomorrow")
        XCTAssertEqual(PlannerReminders.ladderTitle("Essay", rung: .morningOf), "Essay today")
    }

    func testTheBodyCarriesKindAndBlock() {
        let r = PlannerReminders.ladderRequests(for: big(due: "2026-10-20", block: "C"), now: now, timeZone: utc)
        XCTAssertEqual(r.first?.body, "Test · Block C")
    }

    // MARK: - The note

    private func note(_ item: PlannerItem, _ permission: ReminderPermission = .granted, appOn: Bool = true) -> String? {
        PlannerReminders.note(for: item, now: now, permission: permission, appNotificationsOn: appOn, timeZone: utc)
    }

    func testTheNoteForABigDeadline() {
        XCTAssertNil(note(big(due: "2026-10-20")))
        XCTAssertNil(note(big(due: "2026-10-20", rungs: [])), "all off is a choice, not a problem")
        XCTAssertEqual(note(big(due: "2026-09-30")), "Those times have already passed, so there won't be a reminder.")
        XCTAssertEqual(note(big(due: "2026-10-20"), .denied), "Notifications are off for Knight Life in your iPhone's Settings, so these reminders won't show up.")
        XCTAssertEqual(note(big(due: "2026-10-20"), .granted, appOn: false), "Notifications are turned off in Knight Life's settings, so these reminders won't show up.")
    }

    func testRungsThatAreOnButAllGoneIsSaidButOnlyTheOnesTheStudentChose() {
        // Due in 2 days with only the week and 3-day rungs on: both gone.
        XCTAssertEqual(note(big(due: "2026-10-06", rungs: [.week, .threeDays])), "Those times have already passed, so there won't be a reminder.")
        XCTAssertNil(note(big(due: "2026-10-06", rungs: [.week, .morningOf])), "the morning rung is still ahead")
    }
}

final class PlannerLadderModelTests: XCTestCase {
    private func item(_ mutate: (inout PlannerItem) -> Void = { _ in }) -> PlannerItem {
        var v = PlannerItem(id: "i", kind: .test, title: "T", dueDate: "2026-10-20", createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        mutate(&v); return v
    }

    func testRungsRoundTripForABigDeadline() {
        let original = item { $0.isBig = true; $0.rungs = [.dayBefore, .morningOf] }
        XCTAssertEqual(PlannerItem(id: "i", data: original.firestoreData)?.rungs, [.dayBefore, .morningOf])
    }

    func testAnEmptyLadderIsWrittenAndReadBackAsEmptyNotAsFull() {
        let original = item { $0.isBig = true; $0.rungs = [] }
        XCTAssertEqual((original.firestoreData["rungs"] as? [String]), [])
        XCTAssertEqual(PlannerItem(id: "i", data: original.firestoreData)?.rungs, [])
    }

    func testAnItemWithNoRungsFieldReadsAsAFullLadder() {
        XCTAssertEqual(PlannerItem(id: "i", data: item().firestoreData)?.rungs, Set(LadderRung.allCases))
    }

    func testRungsAreNotWrittenForAnOrdinaryItem() {
        XCTAssertNil(item { $0.rungs = [.week] }.firestoreData["rungs"])
    }

    func testRungsAreWrittenInLadderOrderWhateverTheSetOrder() {
        let data = item { $0.isBig = true; $0.rungs = [.morningOf, .week] }.firestoreData
        XCTAssertEqual(data["rungs"] as? [String], ["week", "morningOf"])
    }

    func testAnUnknownRungFromANewerBuildIsSkippedNotFatal() {
        var data = item { $0.isBig = true }.firestoreData
        data["rungs"] = ["week", "fortnight", "morningOf"]
        XCTAssertEqual(PlannerItem(id: "i", data: data)?.rungs, [.week, .morningOf])
    }

    func testEveryRungHasADistinctLabelAndPosition() {
        XCTAssertEqual(Set(LadderRung.allCases.map { $0.label }).count, 4)
        XCTAssertEqual(LadderRung.allCases.map { $0.position }, [1, 2, 3, 4])
        XCTAssertEqual(LadderRung.allCases.map { $0.daysBefore }, [7, 3, 1, 0])
    }

    func testTheCachePersistsABigDeadlineAndItsRungs() {
        let original = item { $0.isBig = true; $0.reminder = .none; $0.rungs = [.week, .dayBefore] }
        let restored = PlannerReminderCache(decoding: PlannerReminderCache(items: [original]).encoded()).items.first
        XCTAssertEqual(restored?.isBig, true)
        XCTAssertEqual(restored?.rungs, [.week, .dayBefore])
    }

    func testABigItemWithNoPlainReminderIsStillCachedAndAnOrdinaryOneWithoutIsNot() {
        let big = item { $0.isBig = true; $0.reminder = .none }
        let plain = item { $0.isBig = false; $0.reminder = .none }
        XCTAssertEqual(PlannerReminderCache(decoding: PlannerReminderCache(items: [big]).encoded()).items.count, 1)
        XCTAssertEqual(PlannerReminderCache(decoding: PlannerReminderCache(items: [plain]).encoded()).items.count, 0)
    }

    func testACacheSavedByThePreviousBuildStillReads() {
        let old = #"[{"id":"a","kind":"test","title":"t","dueDate":"2026-10-10","reminder":"evening"}]"#
        let item = PlannerReminderCache(decoding: Data(old.utf8)).items.first
        XCTAssertEqual(item?.reminder, .evening)
        XCTAssertEqual(item?.isBig, false)
        XCTAssertEqual(item?.rungs, Set(LadderRung.allCases))
    }

    func testChangingARungCountsAsAChangeForTheCache() {
        var cache = PlannerReminderCache(items: [item { $0.isBig = true }])
        let edited = item { $0.isBig = true; $0.rungs = [.week] }
        XCTAssertTrue(cache.apply(items: [edited], window: ("2026-10-01", "2026-10-31")))
    }
}
