//
//  ScheduleNotifications.swift
//  BBNDaily
//
//  HQ-112: push notifications for schedule changes.
//
//  Every device subscribes to one FCM topic rather than registering a per-device token
//  in Firestore. There is no per-student targeting to do - a snow day affects everyone
//  the same way - so a topic needs no token storage and no new security rules.
//

import FirebaseMessaging

enum ScheduleNotifications {
    static let topic = "schedule-updates"

    /// Subscribes or unsubscribes based on the same "Notifications" switch that already
    /// governs the per-block local reminders in Settings, so there is one on/off, not two.
    static func syncSubscription() {
        if ((LoginVC.blocks["notifs"] ?? "") as? String) == "true" {
            Messaging.messaging().subscribe(toTopic: topic)
        } else {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
    }
}
