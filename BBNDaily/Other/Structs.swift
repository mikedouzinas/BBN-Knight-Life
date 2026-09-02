//
//  Structs.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

// HQ-659: one constant per text field, in one file, instead of a magic number typed
// into each screen's viewDidLoad. The old default (TextFieldVC.maxLength = 10) was
// never a real decision - a screen that forgot to set its own limit silently got a
// ten-character field, and ten characters looks like a working limit rather than a
// mistake. defaultLimit below is a deliberate choice: same as the smallest limit
// anyone actually picked on purpose (className/room, 25), not an arbitrary small
// number nobody chose.
enum FieldLimits {
    static let className = 25
    static let teacherName = 50
    static let roomNumber = 25
    static let homeworkTitle = 60
    static let homeworkBody = 300
    static let scheduleBlockName = 150
    // TimesVC's own limit - it has no visible UITextField in the file (its UI is date
    // pickers), so this looks vestigial rather than protecting real input. Kept as-is,
    // not investigated further here - out of this ticket's actual scope, which is class
    // names specifically.
    static let secretScheduleTimes = 100
    // Shared by the locker number and locker code fields.
    static let lockerField = 10

    static let defaultLimit = className
}

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

// HQ-661: a side menu publication entry as data, so adding one back or hiding one that
// went quiet is a Firestore edit, not a code change and a release. "Schedule" is not one
// of these - it's a fixed, always-first native destination, not something a student
// maintainer edits.
struct SideMenuEntry {
    var title: String
    var iconName: String       // an asset-catalog image name, checked first, or an SF Symbol name
    var textImageName: String?
    var urlString: String?
    var order: Int
    var visible: Bool

    // Today's six publications, exactly as they were hardcoded before this ticket. Used
    // both as the instant-display default (so the menu is never empty while Firestore is
    // still loading) and as the fallback if the document doesn't exist yet, is empty, or
    // fails to read - so a vault with nobody having touched the new collection yet, or a
    // student maintainer typo, degrades to "looks exactly like it did before," never to a
    // blank or broken menu.
    static let defaultPublications: [SideMenuEntry] = [
        SideMenuEntry(title: "The Vanguard", iconName: "vanguardLogo", textImageName: "vanguardTextLogo", urlString: "https://vanguard.bbns.org/", order: 1, visible: true),
        SideMenuEntry(title: "The Spectator", iconName: "spectatorLogo", textImageName: "spectatorTextLogo", urlString: "https://www.spectatorbbn.org/", order: 2, visible: true),
        SideMenuEntry(title: "The Benchwarmer", iconName: "benchwarmerLogo", textImageName: "benchwarmerTextLogo", urlString: "https://bbnbenchwarmer.org/", order: 3, visible: true),
        SideMenuEntry(title: "CHASM", iconName: "bonjour", textImageName: nil, urlString: "https://bbnchasm.com/", order: 4, visible: true),
        SideMenuEntry(title: "POV", iconName: "POVLogo", textImageName: "povTextLogo", urlString: "https://pov.bbns.org/", order: 5, visible: true),
        SideMenuEntry(title: "Merch Store", iconName: "bag.circle.fill", textImageName: nil, urlString: "https://www.amerasport.com/Buckingham-Browne-Nichols-BBN-BBN/departments/1029/", order: 6, visible: true),
    ]
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

// The school year's first and last day of classes, as yyyy/M/d strings.
//
// This exists so the app can tell "a day with nothing published" apart from "a day outside
// the school year entirely". Without it, every gap in the calendar produces a confident
// seven-block Wednesday, which is what students saw all through August 2026.
//
// Absent on purpose is a default. There is no fallback term hardcoded anywhere, because a
// hardcoded year expires silently and then lies. When this is nil the app behaves exactly
// as it did before, which is the safe direction: a missing read shows a schedule that might
// be wrong, rather than telling the whole school there is no class today.
struct Term {
    var startDate: String
    var endDate: String
    // What to call the time outside it. "Summer break" nearly always.
    var reason: String
}

// MARK: The resolved shape of a single school day

// What kind of day this is. The calendar renders each case differently, and notification
// scheduling only fires for .classes.
enum DayKind {
    case classes
    case noSchool(reason: String)
    case image(url: String)
    case weekend
    // Outside the school year. Distinct from .noSchool so the reason is the app's own
    // inference rather than something an admin published, and so it can be told apart in
    // a test and in a bug report.
    case outsideTerm(reason: String)
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
        case .outsideTerm(let r):   return "No Class - \(r)"
        case .image:                return nil
        }
    }
}
