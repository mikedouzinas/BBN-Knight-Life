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
    let blocks: [block]
    let weekday: String
    let date: Date
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
