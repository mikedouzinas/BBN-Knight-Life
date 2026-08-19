//
//  Structs.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

struct WatchClass {
    let Title: String
    let StartTime: String
    let EndTime: String
}

struct Classroom {
    let name: String
    let lat: Double
    let lon: Double
}

struct Announcement {
    let Title: String
    let Date: String
    let timeframe: String?
    let location: String?
    let rightIndicator: Bool
}

struct SchoolTask {
    var title: String
    var description: String
    var dueDate: String
    let isCompleted: Bool
    var index: Int
}

struct settingsBlock {
    let blockName: String
    let className: String
}

struct ProfileCell {
    var title: String
    var data: String
}

struct Libraries {
    let libraries: [Library]
}

struct Library {
    let name: String
    let url: String
}

struct ClassModel {
    var Subject: String
    var Teacher: String
    var Room: String
    var Block: String
}

struct customBlock {
    var isFirstLunch: Bool
    var fullBlock: block
}

struct block {
    var name: String
    var startTime: String
    var endTime: String
    var block: String
}

extension block: Comparable {
    static func < (lhs: block, rhs: block) -> Bool {
        // Compare by start time
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }
        
        // If start times are equal, compare by end time
        if lhs.endTime != rhs.endTime {
            return lhs.endTime < rhs.endTime
        }
        
        // If both start and end times are equal, maintain original order
        return false
    }
}

struct NoSchoolDay {
    let date: String
    let reason: String
}

struct Person {
    let name: String
    let email: String
    let uid: String
}

struct CustomWeekday {
    var blocks: [block]
    let weekday: String?
    let date: Date?
    var hasImage: Bool
}

struct SpecialSchedule {
    var specialSchedules: [block]
    var specialSchedulesL1: [block]
    var reason: String?
    var date: String?
    var imageUrl: String?
    var image: UIImage?
}

struct SideMenuModel {
    var icon: UIImage
    var title: String
    var textImage: UIImage?
}

struct Weekday {
    var L1: [block]
    var L2: [block]
}

// MARK: New schedule v2 format

struct Event {
    var type: String
    var block: String?
    var name: String?
    var startTime: String?
    var endTime: String?
    var filter: [String]?
    var matchMode: String?
    var lunchBlock: String?
    var contents: [Event]?
}

struct Day {
    var type: String
    var blocks: [Event]?
    var reason: String?
    var imageUrl: String?
}

struct Break {
    var reason: String
    var startDate: String
    var endDate: String
}

// MARK: The resolved shape of a single school day

// What kind of day this is. The calendar renders each case differently, and notification
// scheduling only fires for .classes.
enum DayKind {
    case classes
    case noSchool(reason: String)
    case image(url: String)
    case weekend
}

// The output of resolveDay(date:), which is the only place a day is worked out.
// See the comment above resolveDay in Extensions.swift for why one resolver exists.
struct ResolvedDay {
    var blocks: [block]
    var weekdayIndex: Int
    var weekdayName: String
    var date: Date
    var kind: DayKind

    var hasClasses: Bool {
        if case .classes = kind { return !blocks.isEmpty }
        return false
    }

    // The message to show when there are no classes, or nil when there are.
    var emptyMessage: String? {
        switch kind {
        case .classes:              return blocks.isEmpty ? "No Class" : nil
        case .noSchool(let reason): return "No Class - \(reason)"
        case .weekend:              return "No Class - Enjoy your weekend"
        case .image:                return nil
        }
    }
}
