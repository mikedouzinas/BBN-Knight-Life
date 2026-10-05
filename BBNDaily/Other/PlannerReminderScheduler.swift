//
//  PlannerReminderScheduler.swift
//  BBNDaily
//
//  HQ-2185. The part of planner reminders that talks to iOS: keeping the cache, and handing the
//  plan to UNUserNotificationCenter. The decisions (when, which, how many) are in PlannerReminders,
//  which is unit tested; this file only carries them out.
//
//  Reminders are never scheduled from here on their own. setNotifications() calls
//  `scheduleCurrentPlan()` after the class reminders, because it clears every pending notification
//  first and rebuilds both from scratch, and the 64-notification budget has to be split in one place.
//

import UIKit
import UserNotifications

enum PlannerReminderScheduler {

    private static let defaultsKey = "plannerReminderCache.v1"

    /// Touched from the main thread only: every caller is a view controller.
    private static var cache: PlannerReminderCache = {
        PlannerReminderCache(decoding: UserDefaults.standard.data(forKey: defaultsKey))
    }()

    // MARK: Keeping the cache

    /// A planner read that covered `window`. Returns whether any reminder could now be different,
    /// in which case the caller reschedules.
    static func didLoad(items: [PlannerItem], window: (start: String, end: String)) -> Bool {
        let changed = cache.apply(items: items, window: window)
        if changed { persist() }
        return changed
    }

    /// A save the student just made, applied immediately instead of waiting for the server.
    static func didSave(_ item: PlannerItem) -> Bool {
        let changed = cache.upsert(item)
        if changed { persist() }
        return changed
    }

    static func didDelete(id: String) -> Bool {
        let changed = cache.remove(id: id)
        if changed { persist() }
        return changed
    }

    /// On sign-out: the next person to sign in on this phone must not inherit the last one's reminders.
    static func clear() {
        cache = PlannerReminderCache()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static func persist() {
        UserDefaults.standard.set(cache.encoded(), forKey: defaultsKey)
    }

    // MARK: Scheduling

    /// What setNotifications() should reserve room for, and then schedule. Empty when the student
    /// has notifications off, so the toggle turns planner reminders off with the rest.
    static func currentPlan(notificationsOn: Bool, now: Date = Date()) -> [ReminderRequest] {
        notificationsOn ? PlannerReminders.plan(items: cache.items, now: now) : []
    }

    /// Adds `plan` as local notifications. Called right after setNotifications() has cleared
    /// everything pending, so these are always added fresh.
    static func schedule(_ plan: [ReminderRequest]) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        for request in plan {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            ) { error in
                if let error = error { print("planner reminder \(request.identifier) failed to schedule: \(error)") }
            }
        }
    }

    // MARK: Permission

    static func permission(completion: @escaping (ReminderPermission) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let result: ReminderPermission
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: result = .granted
            case .denied: result = .denied
            default: result = .unknown
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Asks once, the first time a student picks a reminder, rather than leaving it to chance that
    /// the app asked at some earlier point. Does nothing if already decided either way.
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static var appNotificationsOn: Bool {
        ((LoginVC.blocks["notifs"] as? String) ?? "") == "true"
    }
}
