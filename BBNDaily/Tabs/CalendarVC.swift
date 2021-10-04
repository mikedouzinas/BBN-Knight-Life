//
//  CalendarVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.
//

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit
import SkeletonView

class CalendarVC: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentDay.count
    }
    var xc = 0
    func getTimes(x: block) -> [Date] {
        let time = x.reminderTime.prefix(5)
        let time1 = x.startTime.prefix(5)
        let time2 = x.endTime.prefix(5)
        let m = time.replacingOccurrences(of: time.prefix(3), with: "")
        let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
        let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
        var amOrPm = 0
        var amOrPm1 = 0
        var amOrPm2 = 0
        if x.reminderTime.contains("pm") && !time.prefix(2).contains("12"){
            amOrPm = 12
        }
        if x.startTime.contains("pm") && !time1.prefix(2).contains("12"){
            amOrPm1 = 12
        }
        if x.endTime.contains("pm") && !time2.prefix(2).contains("12") {
            amOrPm2 = 12
        }
        let calendar = Calendar.current
        let now = Date()
        let t = calendar.date(
            bySettingHour: ((Int(time.prefix(2)) ?? 0)+amOrPm),
            minute: (Int(m) ?? 0),
            second: 0,
            of: now)!
        let t1 = calendar.date(
            bySettingHour: ((Int(time1.prefix(2)) ?? 0)+amOrPm1),
            minute: (Int(m1) ?? 0),
            second: 0,
            of: now)!
        let t2 = calendar.date(
            bySettingHour: ((Int(time2.prefix(2)) ?? 0)+amOrPm2),
            minute: (Int(m2) ?? 0),
            second: 0,
            of: now)!
        return [now, t, t1, t2]
    }
    func setTimes(recursive: Bool) {
        xc+=1
        var i = 0
        for x in todayBlocks {
            let big = getTimes(x: x)
            let now = big[0]
            var t = big[1]
            if i == 0 {
                t = Calendar.current.date(byAdding: .hour, value: -12, to: t) ?? t
            }
            let t1 = big[2]
            i+=1
            let t2 = big[3]
            if now.isBetweenTimeFrame(date1: t, date2: t2) {
                currentBlock = x
                var name = ""
                if currentBlock.block != "N/A" {
                    var className = (LoginVC.blocks[currentBlock.block] as? String) ?? ""
                    if className == "" {
                        className = "[\(currentBlock.block) Class]"
                    }
                    else if className.contains("~") {
                        let array = className.getValues()
                        className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                    }
                    name = className
                }
                else {
                    name = "\(currentBlock.name)"
                }
                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .abbreviated
                formatter.zeroFormattingBehavior = .dropAll
                formatter.allowedUnits = [.day, .hour, .minute, .second]
                formatter.maximumUnitCount = 2
                if now.isBetweenTimeFrame(date1: t, date2: t1) {
                    let interval = Date().getTimeBetween(to: t1)
                    self.navigationItem.title = "\(formatter.string(from: interval)!) Until \(name)"
                }
                else {
                    let interval = Date().getTimeBetween(to: t2)
                    self.navigationItem.title = "\(formatter.string(from: interval)!) left in \(name)"
                }
            }
            i+=1
        }
        setOld()
        if currentWeekday.isEmpty {
            var z = 0
            var currDate = Date()
            for x in LoginVC.bigArray {
                if z != 0 {
                    currDate = Calendar.current.date(byAdding: .day, value: 1, to: currDate) ?? Date()
                    if !x.blocks.isEmpty {
                        currentWeekday = x.blocks
                        dayOverBlocks = x.blocks
                        calendar.select(currDate)
                        setCurrentday(date: currDate, completion: { _ in
                            self.ScheduleCalendar.reloadData()
                        })
                        self.navigationItem.title = "Next Day of Classes: \(x.weekday.capitalized)"
                        z-=1
                        break
                    }
                }
                z+=1
            }
            if z == LoginVC.bigArray.count {
                self.navigationItem.title = "My Schedule"
            }
        }
        ScheduleCalendar.refreshControl?.endRefreshing()
        if recursive {
            Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [self] timer in
                setTimes(recursive: true)
                ScheduleCalendar.reloadData()
            }
        }
        else {
            ScheduleCalendar.reloadData()
        }
    }
    var dayOverBlocks = [block]()
    var dayIsOver = false
    func setOld() {
        
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        var y = 0
        for x in currentWeekday {
            let big = getTimes(x: x)
            let t2 = big[3]
            if currentDate == stringDate {
                if Date() > t2 {
                    currentWeekday.remove(at: y)
                    y-=1
                }
                if currentBlock.reminderTime == x.reminderTime && y == currentWeekday.count {
                    currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n", reminderTime: "3", length: 0)
                    self.navigationItem.title = "My Schedule"
                }
            }
            y+=1
        }
        if currentWeekday.isEmpty {
            dayIsOver = true
        }
    }
    var todayBlocks = [block]()
    var currentWeekday = [block(name: "", startTime: "", endTime: "", block: "", reminderTime: "", length: 0)]
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        let thisBlock = currentDay[indexPath.row]
        var isLunch = false
        if thisBlock.name.lowercased().contains("lunch") {
            isLunch = true
        }
        cell.configure(with: currentDay[indexPath.row], isLunch: isLunch, selectedDay: selectedDay)
        
        cell.selectionStyle = .none
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        
        if currentDate == stringDate {
            let calendar = Calendar.current
            let time2 = currentDay[indexPath.row].endTime.prefix(5)
            let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
            var amOrPm2 = 0
            if currentDay[indexPath.row].endTime.contains("pm") && !time2.prefix(2).contains("12") {
                amOrPm2 = 12
            }
            let t2 = calendar.date(
                bySettingHour: ((Int(time2.prefix(2)) ?? 0)+amOrPm2),
                minute: (Int(m2) ?? 0),
                second: 0,
                of: Date())!
            let time = currentDay[indexPath.row].reminderTime.prefix(5)
            let m = time.replacingOccurrences(of: time.prefix(3), with: "")
            var amOrPm = 0
            if currentDay[indexPath.row].reminderTime.contains("pm") && !time.prefix(2).contains("12"){
                amOrPm = 12
            }
            let now = Date()
            let t = calendar.date(
                bySettingHour: ((Int(time.prefix(2)) ?? 0)+amOrPm),
                minute: (Int(m) ?? 0),
                second: 0,
                of: now)!
            if now.isBetweenTimeFrame(date1: t, date2: t2) {
                currentBlock = currentDay[indexPath.row]
                cell.alpha = 1
                cell.contentView.alpha = 1
                cell.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
                cell.contentView.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
            }
            else {
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
                if Date() > t2 {
                    if !dayIsOver {
                        cell.alpha = 1
                        cell.contentView.alpha = 1
                        currentDay = currentWeekday
                        tableView.reloadData()
                    }
                    else {
                        currentDay = todayBlocks
                        cell.alpha = 0.3
                        cell.contentView.alpha = 0.3
                    }
                }
                else {
                    cell.alpha = 1
                    cell.contentView.alpha = 1
                }
            }
        }
        else {
            cell.backgroundColor = UIColor(named: "background")
            cell.contentView.backgroundColor = UIColor(named: "background")
            if Date() > realCurrentDate {
                cell.alpha = 0.3
                cell.contentView.alpha = 0.3
            }
            else {
                cell.alpha = 1
                cell.contentView.alpha = 1
            }
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let block = currentDay[indexPath.row]
        if block.name.lowercased().contains("lunch") {
            (tableView.cellForRow(at: indexPath) as! blockTableViewCell).animateView()
            self.performSegue(withIdentifier: "Lunch", sender: nil)
        }
        else if block.block != "N/A" {
            if ((LoginVC.blocks["\(block.block)"] as? String) ?? "").contains("~") {
                ClassPopupVC.block = block.block
                self.performSegue(withIdentifier: "class", sender: nil)
            }
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    var currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n", reminderTime: "3", length: 0)
    static var isLunch1 = false
    var calendarIsExpanded = true
    @IBAction func switchCalendar(_ sender: UIBarButtonItem) {
        if calendarIsExpanded {
            CalendarHeightConstraint.constant = 90
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.down")
                self.view.layoutIfNeeded()
            }
            self.calendar.scope = .week
            calendarIsExpanded = false
        }
        else {
            self.calendar.scope = .month
            CalendarHeightConstraint.constant = height
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.up")
                self.view.layoutIfNeeded()
            }
            calendarIsExpanded = true
        }
    }
    @IBOutlet weak var CalendarArrow: UIBarButtonItem!
    var currentDate = ""
    @IBOutlet weak var ScheduleCalendar: UITableView!
    @IBOutlet weak var calendar: FSCalendar!
    static let monday =  [
        block(name: "B", startTime: "08:15am", endTime: "09:00am", block: "B", reminderTime: "08:10am", length: 45),
        block(name: "D", startTime: "09:05am", endTime: "09:50am", block: "D", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "C", startTime: "10:40am", endTime: "11:25am", block: "C", reminderTime: "10:35am", length: 45),
        block(name: "F1", startTime: "11:30am", endTime: "12:15pm", block: "F", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A", reminderTime: "12:45pm", length: 65),
        block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "E", startTime: "02:40pm", endTime: "03:25pm", block: "E", reminderTime: "02:35pm", length: 45)
    ]
    static let mondayL1 =  [
        block(name: "B", startTime: "08:15am", endTime: "09:00am", block: "B", reminderTime: "08:10am", length: 45),
        block(name: "D", startTime: "09:05am", endTime: "09:50am", block: "D", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "C", startTime: "10:40am", endTime: "11:25am", block: "C", reminderTime: "10:35am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "F2", startTime: "12:00pm", endTime: "12:45pm", block: "F", reminderTime: "11:55am", length: 45),
        block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A", reminderTime: "12:45pm", length: 65),
        block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "E", startTime: "02:40pm", endTime: "03:25pm", block: "E", reminderTime: "02:35pm", length: 45)
    ]
    static let tuesday =  [
        block(name: "A", startTime: "08:15am", endTime: "09:00am", block: "A", reminderTime: "08:10am", length: 45),
        block(name: "F", startTime: "09:05am", endTime: "09:50am", block: "F", reminderTime: "09:00am", length: 45),
        block(name: "Wellness Break", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "Extended G", startTime: "10:20am", endTime: "11:25am", block: "G", reminderTime: "10:15am", length: 65),
        block(name: "E1", startTime: "11:30am", endTime: "12:15pm", block: "E", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended B", startTime: "12:50pm", endTime: "01:55pm", block: "B", reminderTime: "12:45pm", length: 65),
        block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "D", startTime: "02:40pm", endTime: "03:25pm", block: "D", reminderTime: "02:35pm", length: 45)
    ]
    static let tuesdayL1 =  [
        block(name: "A", startTime: "08:15am", endTime: "09:00am", block: "A", reminderTime: "08:10am", length: 45),
        block(name: "F", startTime: "09:05am", endTime: "09:50am", block: "F", reminderTime: "09:00am", length: 45),
        block(name: "Wellness Break", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "Extended G", startTime: "10:20am", endTime: "11:25am", block: "G", reminderTime: "10:15am", length: 65),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "E2", startTime: "12:00pm", endTime: "12:45pm", block: "E", reminderTime: "11:55am", length: 45),
        block(name: "Extended B", startTime: "12:50pm", endTime: "01:55pm", block: "B", reminderTime: "12:45pm", length: 65),
        block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "D", startTime: "02:40pm", endTime: "03:25pm", block: "D", reminderTime: "02:35pm", length: 45)
    ]
    static let wednesday =  [
        block(name: "G", startTime: "08:15am", endTime: "09:00am", block: "G", reminderTime: "08:10am", length: 45),
        block(name: "C", startTime: "09:05am", endTime: "09:50am", block: "C", reminderTime: "09:00am", length: 45),
        block(name: "Class Meeting", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended F", startTime: "10:20am", endTime: "11:25am", block: "F", reminderTime: "10:15am", length: 65),
        block(name: "A1", startTime: "11:30am", endTime: "12:15pm", block: "A", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Community Activity", startTime: "12:45pm", endTime: "01:25pm", block: "N/A", reminderTime: "12:40pm", length: 40)
    ]
    static let wednesdayL1 =  [
        block(name: "G", startTime: "08:15am", endTime: "09:00am", block: "G", reminderTime: "08:10am", length: 45),
        block(name: "C", startTime: "09:05am", endTime: "09:50am", block: "C", reminderTime: "09:00am", length: 45),
        block(name: "Class Meeting", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended F", startTime: "10:20am", endTime: "11:25am", block: "F", reminderTime: "10:15am", length: 65),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 45),
        block(name: "A2", startTime: "12:00pm", endTime: "12:45pm", block: "A", reminderTime: "11:55am", length: 25),
        block(name: "Community Activity", startTime: "12:45pm", endTime: "01:25pm", block: "N/A", reminderTime: "12:40pm", length: 40)
    ]
    static let thursday =  [
        block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C", reminderTime: "08:10am", length: 45),
        block(name: "B", startTime: "09:05am", endTime: "09:50am", block: "B", reminderTime: "09:00am", length: 45),
        block(name: "Advisory", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended D", startTime: "10:20am", endTime: "11:25am", block: "D", reminderTime: "10:15am", length: 45),
        block(name: "G1", startTime: "11:30am", endTime: "12:15pm", block: "G", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended E", startTime: "12:50pm", endTime: "01:55pm", block: "E", reminderTime: "12:45pm", length: 65),
        block(name: "Office Hours", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F", reminderTime: "02:35pm", length: 45)
    ]
    static let thursdayL1 =  [
        block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C", reminderTime: "08:10am", length: 45),
        block(name: "B", startTime: "09:05am", endTime: "09:50am", block: "B", reminderTime: "09:00am", length: 45),
        block(name: "Advisory", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended D", startTime: "10:20am", endTime: "11:25am", block: "D", reminderTime: "10:15am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "G2", startTime: "12:00pm", endTime: "12:45pm", block: "G", reminderTime: "11:55am", length: 45),
        block(name: "Extended E", startTime: "12:50pm", endTime: "01:55pm", block: "E", reminderTime: "12:45pm", length: 65),
        block(name: "Office Hours", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F", reminderTime: "02:35pm", length: 45)
    ]
    static let friday = [
        block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E", reminderTime: "08:10am", length: 45),
        block(name: "G", startTime: "09:05am", endTime: "09:50am", block: "G", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "B", startTime: "10:40am", endTime: "11:25am", block: "B", reminderTime: "10:35am", length: 45),
        block(name: "D1", startTime: "11:30am", endTime: "12:15pm", block: "D", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended C", startTime: "12:50pm", endTime: "01:55pm", block: "C", reminderTime: "12:45pm", length: 65),
        block(name: "A", startTime: "02:00pm", endTime: "02:45pm", block: "A", reminderTime: "01:55pm", length: 45),
        block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A", reminderTime: "02:45pm", length: 35)
    ]
    static let fridayL1 = [
        block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E", reminderTime: "08:10am", length: 45),
        block(name: "G", startTime: "09:05am", endTime: "09:50am", block: "G", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "B", startTime: "10:40am", endTime: "11:25am", block: "B", reminderTime: "10:35am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "D2", startTime: "12:00pm", endTime: "12:45pm", block: "D", reminderTime: "11:55am", length: 45),
        block(name: "Extended C", startTime: "12:50pm", endTime: "01:55pm", block: "C", reminderTime: "12:45pm", length: 65),
        block(name: "A", startTime: "02:00pm", endTime: "02:45pm", block: "A", reminderTime: "01:55pm", length: 45),
        block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A", reminderTime: "02:45pm", length: 35)
    ]
    @IBOutlet weak var CalendarHeightConstraint: NSLayoutConstraint!
    var currentDay = [block]()
    var height = CGFloat(0)
    @objc private func didPullToRefresh() {
        setTimes(recursive: false)
        ScheduleCalendar.reloadData()
    }
    func configureRefreshPull() {
        ScheduleCalendar.refreshControl = UIRefreshControl()
        ScheduleCalendar.refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
    }
    var v = 1
    override func viewWillAppear(_ animated: Bool) {
        reloadPage()
        v+=1
    }
    @objc func reloadPage() {
        if v != 2 {
            let formatter2 = DateFormatter()
            formatter2.dateFormat = "yyyy-MM-dd"
            formatter2.dateStyle = .short
            let date = formatter2.string(from: Date())
            if date != todaysDate {
                setCurrentday(date: Date(), completion: { [self]result in
                    switch result {
                    case .success(let todBlocks):
                        todaysDate = date
                        calendar.select(Date())
                        self.currentWeekday = todBlocks
                        self.todayBlocks = todBlocks
                        LoginVC.setNotifications()
                        for x in todBlocks {
                            print("\(x.name) \(x.startTime)\n")
                        }
                        ScheduleCalendar.reloadData()
                        setTimes(recursive: false)
                    case .failure(_):
                        print("failed :(")
                    }
                })
            }
            else {
                setCurrentday(date: realCurrentDate, completion: { [self]_ in
                    setTimes(recursive: false)
                    ScheduleCalendar.reloadData()
                })
            }
        }
        
    }
    var todaysDate = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadPage), name: UIApplication.didBecomeActiveNotification, object: nil)
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd"
        formatter2.dateStyle = .short
        todaysDate = formatter2.string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = " MMM d, YYYY, HH:mm:ss"
        v = 2
        ScheduleCalendar.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        height = view.frame.height/4
        CalendarHeightConstraint.constant = height
        configureRefreshPull()
        view.layoutIfNeeded()
        ScheduleCalendar.showsVerticalScrollIndicator = false
        ScheduleCalendar.tableFooterView = UIView(frame: .zero)
        setCurrentday(date: Date(), completion: { [self]result in
            switch result {
            case .success(let todBlocks):
                self.currentWeekday = todBlocks
                self.todayBlocks = todBlocks
                calendar.delegate = self
                calendar.dataSource = self
                ScheduleCalendar.delegate = self
                ScheduleCalendar.dataSource = self
                LoginVC.setNotifications()
                ScheduleCalendar.reloadData()
                setTimes(recursive: true)
                
            case .failure(_):
                print("failed :(")
            }
        })
    }
    func setNotif() {
        let hours = 13
        var dateComponents = DateComponents()
        dateComponents.hour = hours
        dateComponents.minute = 13
        dateComponents.second = 35
        dateComponents.timeZone = .current
        dateComponents.weekday = 6
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 2
        let content = UNMutableNotificationContent()
        content.title = "5 Minutes Until B Block"
        content.sound = UNNotificationSound.default
        
        let randomIdentifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
        
        // 3
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                print("something went wrong")
            }
        }
    }
    static let vacationDates = [
        NoSchoolDay(date: "Monday, September 6, 2021", reason: "Labor Day"),
        NoSchoolDay(date: "Tuesday, September 7, 2021", reason: "Rosh Hashanah"),
        NoSchoolDay(date: "Thursday, September 16, 2021", reason: "Yom Kippur"),
        NoSchoolDay(date: "Monday, October 11, 2021", reason: "Indigenous Peoples Day"),
        NoSchoolDay(date: "Tuesday, October 12, 2021", reason: "Professional Day"),
        NoSchoolDay(date: "Thursday, November 11, 2021", reason: "Veterans Day"),
        NoSchoolDay(date: "Thursday, November 25, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Friday, November 26, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Tuesday, January 4, 2022", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Monday, January 17, 2022", reason: "MLK Jr. Day"),
        NoSchoolDay(date: "Monday, February 21, 2022", reason: "Presidents Day"),
        NoSchoolDay(date: "Tuesday, February 22, 2022", reason: "Professional Day"),
        NoSchoolDay(date: "Monday, April 18, 2022", reason: "Patriots Day"),
        NoSchoolDay(date: "Monday, May 30, 2022", reason: "Memorial Day")
    ]
    var selectedDay = 0
    var realCurrentDate = Date()
    func setCurrentday(date: Date, completion: @escaping (Swift.Result<[block], Error>) -> Void) {
        realCurrentDate = date
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd"
        formatter2.dateStyle = .short
        let stringDate1 = formatter2.string(from: date)
        currentDate = stringDate1
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .full
        let stringDate = formatter1.string(from: date)
        let weekDay = stringDate.prefix(upTo: formatter1.string(from: date).firstIndex(of: ",")!)
        let bigArray = LoginVC.getLunchDays()
        let monday = bigArray[0]
        let tuesday = bigArray[1]
        let wednesday = bigArray[2]
        let thursday = bigArray[3]
        let friday = bigArray[4]
        switch weekDay {
        case "Monday":
            currentDay = monday
            selectedDay = 0
        case "Tuesday":
            currentDay = tuesday
            selectedDay = 1
        case "Wednesday":
            currentDay = wednesday
            selectedDay = 2
        case "Thursday":
            currentDay = thursday
            selectedDay = 3
        case "Friday":
            currentDay = friday
            selectedDay = 4
        default:
            currentDay = [block]()
            selectedDay = 10
        }
        if currentDay.isEmpty {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your Weekend")
        }
        else {
            ScheduleCalendar.restore()
        }
        for x in CalendarVC.vacationDates {
            if stringDate.lowercased() == x.date.lowercased() {
                currentDay = [block]()
                ScheduleCalendar.restore()
                ScheduleCalendar.setEmptyMessage("No Class - \(x.reason)")
                completion(.success(currentDay))
                return
            }
        }
        if date.isBetweenTimeFrame(date1: "18 Dec 2021 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Jan 2022 04:00".dateFromMultipleFormats() ?? Date()) || date.isBetweenTimeFrame(date1: "12 Mar 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "27 Mar 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = [block]()
            ScheduleCalendar.restore()
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy Break!")
            completion(.success(currentDay))
            return
        }
        
        for x in LoginVC.specialSchedules {
            if x.key.lowercased() == stringDate.lowercased() {
                self.currentDay = x.value
                if !((LoginVC.blocks["l-\(weekDay.lowercased())"] as? String) ?? "").lowercased().contains("2") {
                    let obj = LoginVC.specialSchedulesL1[x.key]
                    self.currentDay = obj ?? [block]()
                    completion(.success(self.currentDay))
                    return
                }
                if self.currentDay.isEmpty {
                    ScheduleCalendar.restore()
                    ScheduleCalendar.setEmptyMessage("No Class - \(LoginVC.specialDayReasons[x.key] ?? "No Reason")")
                }
                completion(.success(self.currentDay))
                return
            }
        }
        completion(.success(self.currentDay))
        return
    }
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setOld()
        setCurrentday(date: date, completion: { _ in
            self.ScheduleCalendar.reloadData()
        })
        
    }
}

struct block {
    let name: String
    let startTime: String
    let endTime: String
    let block: String
    let reminderTime: String
    let length: Int
}

struct NoSchoolDay {
    let date: String
    let reason: String
}

class blockTableViewCell: UITableViewCell {
    static let identifier = "blockTableViewCell"
    
    private let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.minimumScaleFactor = 0.5
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let BlockLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let RightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(named: "gold")
        label.minimumScaleFactor = 0.8
        label.textAlignment = .right
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let BottomRightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.minimumScaleFactor = 0.8
        label.textColor = UIColor(named: "lightGray")
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(BlockLabel)
        contentView.addSubview(RightLabel)
        contentView.addSubview(BottomRightLabel)
        contentView.backgroundColor = UIColor(named: "background")
        
        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    var constraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        constraint = TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        constraint.isActive = true
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: RightLabel.leftAnchor, constant: -2).isActive = true
        BlockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        RightLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        RightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        RightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        BottomRightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BottomRightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure (with viewModel: ClassModel){
        BlockLabel.isHidden = false
        BottomRightLabel.isHidden = false
        RightLabel.isHidden = false
        TitleLabel.text = viewModel.Subject
        BlockLabel.text = viewModel.Teacher
        RightLabel.text = viewModel.Room
        BottomRightLabel.text = "\(viewModel.Block.capitalized) Block"
    }
    func configure(with viewModel: Person) {
        BlockLabel.isHidden = false
        RightLabel.isHidden = true
        BottomRightLabel.isHidden = true
        TitleLabel.text = viewModel.name
        BlockLabel.text = viewModel.email
    }
    func configure (with viewModel: block, isLunch: Bool, selectedDay: Int){
        RightLabel.isHidden = false
        if viewModel.block != "N/A" {
            BlockLabel.isHidden = false
            var className = LoginVC.blocks[viewModel.block] as? String
            if className == "" {
                className = "[\(viewModel.block) Class]"
            }
            var text = "Update classes in settings to see details"
            if (className ?? "").contains("~") {
                let array = (className ?? "").getValues()
                className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                text = "Press for details"
               
                if !(LoginVC.classMeetingDays["\(viewModel.block.lowercased())"]?[selectedDay] ?? true) {
                    className = "\(viewModel.name)"
                }
            }
            TitleLabel.text = className
            BlockLabel.text = "\(viewModel.name)"
            BottomRightLabel.isHidden = false
            BottomRightLabel.text = text
        }
        else {
            BottomRightLabel.isHidden = true
            TitleLabel.text = "\(viewModel.name)"
            if isLunch {
                BlockLabel.isHidden = false
                BlockLabel.text = "Press for Current Menu"
            }
            else {
                if viewModel.name.lowercased().contains("advisory") {
                    TitleLabel.text = "\(viewModel.name) \(LoginVC.blocks["room-advisory"] ?? "")"
                }
                BlockLabel.isHidden = true
            }
        }
        RightLabel.text = "\(viewModel.startTime) \u{2192} \(viewModel.endTime)"
    }
}

class LunchMenuVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let storage = FirebaseStorage.Storage.storage()
        let reference = storage.reference(withPath: "lunchmenus/lunchmenu-allergy.docx")
        reference.downloadURL(completion: { [self] (url, error) in
            if let error = error {
                print(error)
            }
            else {
                print("the url is: \(url!.absoluteString)")
                let urlstring = url!.absoluteString
                webView.backgroundColor = UIColor.white
                view.addSubview(webView)
                webView.frame = view.bounds
                webView.navigationDelegate = self
                guard let url = URL(string: urlstring) else {
                    return
                }
                webView.load(URLRequest(url: url))
                showLoaderView()
            }
        })
        view.backgroundColor = UIColor.white
        
    }
}

class ClassPopupVC: UIViewController, UITableViewDelegate, SkeletonTableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return blockTableViewCell.identifier
    }
    static var block = ""
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        cell.configure(with: members[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Members"
    }
    private var members = [Person]()
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setMembers()
        configureTableView()
    }
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let person = members[indexPath.row]
        if person.uid != "N/A" && person.uid != "" {
            let db = Firestore.firestore()
            let user = db.collection("users").document("\(person.uid)")
            user.getDocument(completion: { [self] (document, error) in
                if let document = document, document.exists {
                    if (document.data()?["publicClasses"] as? String ?? "false") == "true" {
                        let popup = PersonPopupVC()
                        var a = (document.data()?["A"] as? String ?? "A Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var b = (document.data()?["B"] as? String ?? "B Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var c = (document.data()?["C"] as? String ?? "C Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var d = (document.data()?["D"] as? String ?? "D Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var e = (document.data()?["E"] as? String ?? "E Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var f = (document.data()?["F"] as? String ?? "F Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var g = (document.data()?["G"] as? String ?? "G Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        if a.isEmpty {
                            a = "--"
                        }
                        if b.isEmpty {
                            b = "--"
                        }
                        if c.isEmpty {
                            c = "--"
                        }
                        if d.isEmpty {
                            d = "--"
                        }
                        if e.isEmpty {
                            e = "--"
                        }
                        if f.isEmpty {
                            f = "--"
                        }
                        if g.isEmpty {
                            g = "--"
                        }
                        let text = "A: \(a.prefix(a.count-2))\nB: \(b.prefix(b.count-2))\nC: \(c.prefix(c.count-2))\nD: \(d.prefix(d.count-2))\nE: \(e.prefix(e.count-2))\nF: \(f.prefix(f.count-2))\nG: \(g.prefix(g.count-2))"
                        popup.textView.text = text
                        popup.navigationItem.title = "\(person.name.trimmingCharacters(in: .whitespacesAndNewlines))'s Classes"
                        show(popup, sender: nil)
                    }
                    else {
                        ProgressHUD.colorAnimation = .red
                        ProgressHUD.showFailed("This user has public classes turned off")
                    }
                } else {
                    print("Document does not exist, no members to add!")
                }
            })
        }
        else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("This user has not set up this shared class")
        }
    }
    @IBOutlet public var HeightConstraint: NSLayoutConstraint!
    func setMembers() {
        let db = Firestore.firestore()
        let memberDocs = db.collection("classes")
        let blockName = (LoginVC.blocks["\(ClassPopupVC.block)"] as? String) ?? "N/A"
        let arr = blockName.getValues()
        self.navigationItem.title = "\(arr[0]) \(arr[1].replacingOccurrences(of: "N/A", with: ""))"
        let doc = memberDocs.document(blockName)
        doc.getDocument(completion: { [self] (document, error) in
            members = [Person]()
            if let document = document, document.exists {
                let array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                let homeworkText = (document.data()?["homework"] as? String) ?? ""
                TextView.text = homeworkText
                for x in array {
                    members.append(Person(name: (x["name"] ?? ""), email: (x["email"] ?? ""), uid: x["uid"] ?? "N/A"))
                }
            } else {
                print("Document does not exist, no members to add!")
            }
            TextView.stopSkeletonAnimation()
            tableView.stopSkeletonAnimation()
            view.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(0.25))
            tableView.reloadData()
        })
    }
    @IBOutlet public var TextView: UITextView!
    func configureTableView() {
        HeightConstraint.constant = view.frame.height/4
        view.layoutIfNeeded()
        tableView.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isSkeletonable = true
        tableView.showAnimatedGradientSkeleton()
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = 50
        TextView.isSkeletonable = true
        TextView.showAnimatedGradientSkeleton()
        TextView.skeletonCornerRadius = 4
    }
    @IBAction func editText(_ sender: UIButton) {
        TextEditVC.link = self
        self.performSegue(withIdentifier: "edit", sender: nil)
    }
}

struct Person {
    let name: String
    let email: String
    let uid: String
}
class TextEditVC: UIViewController {
    static var link: ClassPopupVC!
    @IBOutlet weak var TextView: UITextView!
    override func viewDidLoad() {
        TextView.text = TextEditVC.link.TextView.text
        TextView.becomeFirstResponder()
    }
    @IBAction func save() {
        let db = Firestore.firestore()
        let memberDocs = db.collection("classes")
        let blockName = (LoginVC.blocks["\(ClassPopupVC.block)"] as? String) ?? "N/A"
        let doc = memberDocs.document(blockName)
        doc.setData(["homework":"\(TextView.text ?? "")"], merge: true)
        TextEditVC.link.TextView.text = "\(TextView.text ?? "")"
        TextView.resignFirstResponder()
        self.navigationController?.popViewController(animated: true)
    }
}

class PersonPopupVC: UIViewController {
    public let textView = UITextView()
    override func viewDidLoad() {
        textView.frame = view.bounds
        view.addSubview(textView)
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 20, weight: .regular)
        textView.textColor = UIColor(named: "inverse")
        textView.backgroundColor = UIColor(named: "background")
    }
}
