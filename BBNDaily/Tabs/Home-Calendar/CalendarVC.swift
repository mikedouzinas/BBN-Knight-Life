//
//  CalendarVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit
import SkeletonView

class CalendarVC: AuthVC, FSCalendarDelegate, FSCalendarDataSource, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, WKNavigationDelegate {
    @IBOutlet var sideMenuBtn: UIBarButtonItem!
    @IBOutlet var webView: WKWebView!
    static var hasPressedSideMenu = false
//    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//        print("complete?")
//        setWatchClasses(todBlocks: CalendarVC.todayBlocks)
//    }
    
//    func sessionDidBecomeInactive(_ session: WCSession) {
//        print("inactive")
//    }
//
//    func sessionDidDeactivate(_ session: WCSession) {
//        print("deactivated?")
//    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentDay.count
    }
    var xc = 0
    func setTimes(recursive: Bool) {
        if isActive {
            xc+=1
            var i = 0
            for x in CalendarVC.todayBlocks {
                let big = getReturnDates(currBlock: x)
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
                            className = "[\(currentBlock.block) Block]"
                        }
                        else if className.contains("~") {
                            let array = className.getValues()
                            className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                        }
                        if (LoginVC.classMeetingDays["\(currentBlock.block.lowercased())"]?.count ?? 0) > selectedDay && !(LoginVC.classMeetingDays["\(currentBlock.block.lowercased())"]?[selectedDay] ?? true) {
                            className = "Free"
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
            
            if currentWeekday.blocks.isEmpty && currentWeekday.hasImage == false { // i need to check if the active day is an image
                var z = 0
                var currDate = Date()
                let currTitle = self.navigationItem.title
                for x in LoginVC.upcomingDays {
                    if z != 0 {
                        currDate = Calendar.current.date(byAdding: .day, value: 1, to: currDate) ?? Date()
                        let currVal = "Next Day of Classes: \(x.weekday?.capitalized ?? "")"
                        if !x.blocks.isEmpty {
                            if currTitle != currVal {
                                currentWeekday.blocks = x.blocks
                                dayOverBlocks = x.blocks
                                calendar.select(currDate)
                                setCurrentday(date: currDate, shouldEdit: false, completion: { _ in
                                    self.ScheduleCalendar.reloadData()
                                })
                                self.navigationItem.title = "Next Day of Classes: \(x.weekday?.capitalized ?? "")"
                                z-=1
                            }
                            break
                        }
                    }
                    z+=1
                }
                if z == LoginVC.upcomingDays.count {
                    self.navigationItem.title = "My Schedule"
                }
            }
            ScheduleCalendar.refreshControl?.endRefreshing()
        }
        if recursive && (LoginVC.blocks["uid"] as? String) != "" {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [self] timer in
                setTimes(recursive: true)
                if isActive {
//                    print("reloading...")
                    ScheduleCalendar.reloadData()
                }
            }
        }
        else {
            ScheduleCalendar.reloadData()
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("isActive = false")
        isActive = false
    }
    @objc func leaveApp() {
        print("isActive = false")
        isActive = false
    }
    var isActive = true
    var dayOverBlocks = [block]()
    var dayIsOver = false
    func setOld() {
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        var y = 0
        for x in currentWeekday.blocks {
            let big = getReturnDates(currBlock: x)
            let t2 = big[3]
            if currentDate == stringDate {
                if Date() > t2 {
                    currentWeekday.blocks.remove(at: y)
                    y-=1
                }
                if currentBlock.startTime == x.startTime && y == currentWeekday.blocks.count {
                    currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n")
                    self.navigationItem.title = "My Schedule"
                }
            }
            y+=1
        }
        if currentWeekday.blocks.isEmpty {
            dayIsOver = true
        }
    }
    func getReturnDates(currBlock: block) -> [Date] {
        // end time
        let currDate = Date()
        // not during today
        var endTime = currBlock.endTime.dateFromMultipleFormats() ?? Date()
        var startTime = currBlock.startTime.dateFromMultipleFormats() ?? Date()
        var reminderTime = startTime
        if !currBlock.name.lowercased().contains("passing") {
            reminderTime = Calendar.current.date(byAdding: .minute, value: -5, to: startTime)!
        }
        reminderTime.addEventsToToday()
        startTime.addEventsToToday()
        endTime.addEventsToToday()
        return [currDate, reminderTime, startTime, endTime]
    }
    static var todayBlocks = [block]()
    var currentWeekday = CustomWeekday(blocks: [block](), weekday: nil, date: nil, hasImage: false)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: coverTableViewCell.identifier, for: indexPath) as? coverTableViewCell else {
            fatalError()
        }
        if indexPath.row > currentDay.count - 1 {
            return coverTableViewCell()
        }
        let thisBlock = currentDay[indexPath.row]
        var isLunch = false
        if thisBlock.name.lowercased().contains("lunch") {
            isLunch = true
        }
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "h:mm a"
        dateformatter.amSymbol = "AM"
        dateformatter.pmSymbol = "PM"
        let dates = getReturnDates(currBlock: currentDay[indexPath.row])
        let t = dates[1]
        let t2 = dates[3]
        let t3 = dates[2]

//        dateformatter.string(from: t) // end is t2 and start is t3
        cell.configure(with: block(name: thisBlock.name, startTime: dateformatter.string(from: t3), endTime: dateformatter.string(from: t2), block: thisBlock.block), isLunch: isLunch, selectedDay: selectedDay)
        cell.selectionStyle = .none
        
        if currentDate == stringDate {
            
            if Date().isBetweenTimeFrame(date1: t, date2: t2) {
                currentBlock = currentDay[indexPath.row]
                cell.alpha = 1
                cell.contentView.alpha = 1
                cell.backView.backgroundColor = UIColor(named: "current-cell")?.withAlphaComponent(0.1)
            }
            else {
                cell.backView.backgroundColor = .clear
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
                if Date() > t2 {
                    if !dayIsOver {
                        cell.alpha = 1
                        cell.contentView.alpha = 1
                        currentDay = currentWeekday.blocks
                        tableView.reloadData()
                    }
                    else {
                        currentDay = CalendarVC.todayBlocks
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
            cell.backView.backgroundColor = .clear
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
    fileprivate lazy var scopeGesture: UIPanGestureRecognizer = {
        [unowned self] in
        let panGesture = UIPanGestureRecognizer(target: self.calendar, action: #selector(self.calendar.handleScopeGesture(_:)))
        panGesture.delegate = self
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 2
        return panGesture
    }()
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let block = currentDay[indexPath.row]
        if block.name.lowercased().contains("lunch") {
            // Set LunchMenuVC.week to the date of the current week's Monday in the form "m/d"
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            let lunchDay = Calendar.current.component(.weekday, from: realCurrentDate)
            let daysToSubtract = lunchDay - 2
            let monday = Calendar.current.date(byAdding: .day, value: -daysToSubtract, to: realCurrentDate)!
            LunchMenuVC.week = formatter.string(from: monday)
            print(LunchMenuVC.week)
            
            (tableView.cellForRow(at: indexPath) as! coverTableViewCell).animateView()
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
    var currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n")
    static var isLunch1 = false
    var calendarIsExpanded = true
    @IBAction func switchCalendar(_ sender: UIBarButtonItem) {
        if self.calendar.scope == .month {
            self.calendar.setScope(.week, animated: true)
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.down")
                self.view.layoutIfNeeded()
            }
        } else {
            self.calendar.setScope(.month, animated: true)
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.up")
                self.view.layoutIfNeeded()
            }
        }
    }
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        self.CalendarHeightConstraint.constant = bounds.height
        self.view.layoutIfNeeded()
    }
    @IBOutlet weak var CalendarArrow: UIBarButtonItem!
    var currentDate = ""
    @IBOutlet weak var ScheduleCalendar: UITableView!
    @IBOutlet weak var calendar: FSCalendar!
    @IBOutlet weak var dragView: UIView!
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
        super.viewWillAppear(animated)
        isActive = true
        reloadPage()
        v+=1
    }
    @objc func screenReopened() {
        isActive = true
        print("screen has reopened -> restarting the page")
        reloadPage()
    }
    @objc func reloadPage() {
        if v != 2 {
            let formatter2 = DateFormatter()
            formatter2.dateFormat = "yyyy-MM-dd"
            formatter2.dateStyle = .short
            let date = formatter2.string(from: Date())
            print("\(date) vs \(todaysDate)")
            if date != todaysDate {
                NotificationCenter.default.removeObserver(self)
                todaysDate = date
                updateSpecialSchedules(completion: { [self] result in
                    switch result {
                    case .success(_):
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let vc = storyboard.instantiateViewController(withIdentifier: "CalendarVC")
                        var viewcontrollers = self.navigationController?.viewControllers ?? [UIViewController]()
                        if !viewcontrollers.isEmpty {
                            viewcontrollers.removeAll()
                        }
                        viewcontrollers.append(vc)
                        self.navigationController?.setViewControllers(viewcontrollers, animated: false)
                    case .failure(let err):
                        print("failed to get sched \(err)")
                    }
                })
            }
            else {
                setCurrentday(date: realCurrentDate, shouldEdit: false, completion: { [self]_ in
                    setTimes(recursive: false)
                    print("normal reload")
                    ScheduleCalendar.reloadData()
                })
            }
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let shouldBegin = self.ScheduleCalendar.contentOffset.y <= -self.ScheduleCalendar.contentInset.top
        if shouldBegin {
            let velocity = self.scopeGesture.velocity(in: self.view)
            switch self.calendar.scope {
            case .month:
                UIView.animate(withDuration: 0.5) {
                    self.CalendarArrow.image = UIImage(systemName: "chevron.down")
                    self.view.layoutIfNeeded()
                }
                return velocity.y < 0
            case .week:
                UIView.animate(withDuration: 0.5) {
                    self.CalendarArrow.image = UIImage(systemName: "chevron.up")
                    self.view.layoutIfNeeded()
                }
                return velocity.y > 0
            @unknown default:
                print("boom failed")
            }
        }
        return shouldBegin
    }
    @IBOutlet weak var roundedView: UIView!
    var todaysDate = ""
    var viewIsNew = false
    var watchClasses = [WatchClass]()
    override func viewDidLoad() {
        super.viewDidLoad()
        viewIsNew = true
        if AuthVC.isFirstTime || viewIsNew {
            AuthVC.isFirstTime = false
            viewIsNew = false
            NotificationCenter.default.addObserver(self, selector: #selector(screenReopened), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(leaveApp), name: UIApplication.willResignActiveNotification, object: nil)
        }
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.backBarButtonItem?.tintColor = .white
        self.calendar.scope = .week
        navigationController?.navigationBar.scrollEdgeAppearance?.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        self.dragView.layer.masksToBounds = true
        self.dragView.layer.cornerRadius = 2
        self.roundedView.clipsToBounds = true
        self.roundedView.layer.cornerRadius = 12
        self.view.addGestureRecognizer(self.scopeGesture)
        self.ScheduleCalendar.panGestureRecognizer.require(toFail: self.scopeGesture)
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd"
        formatter2.dateStyle = .short
        todaysDate = formatter2.string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = " MMM d, YYYY, HH:mm:ss"
        v = 2
        ScheduleCalendar.register(coverTableViewCell.self, forCellReuseIdentifier: coverTableViewCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        height = view.frame.height/4
        configureRefreshPull()
        ScheduleCalendar.showsVerticalScrollIndicator = false
        ScheduleCalendar.tableFooterView = UIView(frame: .zero)
        setCurrentday(date: Date(), shouldEdit: true, completion: { [self]result in
            switch result {
            case .success(let todBlocks):
                self.currentWeekday.blocks = todBlocks
                CalendarVC.todayBlocks = todBlocks
                calendar.delegate = self
                calendar.dataSource = self
                ScheduleCalendar.delegate = self
                ScheduleCalendar.dataSource = self
                setNotifications()
                ScheduleCalendar.reloadData()
                setTimes(recursive: true)
            case .failure(_):
                print("failed :(")
            }
        })
    }
    var selectedDay = 0
    var realCurrentDate = Date()
    func setCurrentday(date: Date, shouldEdit: Bool, completion: @escaping (Swift.Result<[block], Error>) -> Void) {
        ScheduleCalendar.isHidden = false
        webView.isHidden = true
        realCurrentDate = date
        
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd"
        formatter2.dateStyle = .short
        let stringDate1 = formatter2.string(from: date)
        currentDate = stringDate1
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d" // Use standard format without leading zeros
        let stringDate = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "EEEE"
        let weekday = dateFormatter.string(from: date)
        
        var day = (blocks: [block](), selectedDay: 11)
        
        if let value = LoginVC.specialDays[stringDate] {
            let dayType = value.type
                
            if dayType == "noschool" {
                
                if let reason = value.reason {
                    ScheduleCalendar.setEmptyMessage("No Class - \(reason)")
                } else {
                    ScheduleCalendar.setEmptyMessage("No Class")
                }
                
            } else if dayType == "blocks" {
                
                var weekdayBlocks = [block]()
                for scheduleBlock in value.blocks ?? [] {
                    weekdayBlocks += getNextBlock(scheduleBlock: scheduleBlock) ?? []
                }
                day = (weekdayBlocks, getWeekdayAsInt(weekday))
                
            } else if dayType == "image" {
                
                ScheduleCalendar.isHidden = true
                webView.isHidden = false
                if let url = URL(string: value.imageUrl!) {
                    webView.load(URLRequest(url: url))
                    if shouldEdit {
                        currentWeekday.hasImage = true
                    }
                }
                
            }
            
        } else {
            var found = false
            for singularBreak in LoginVC.breaks {
                if isDateInRange(date: date, breakPeriod: singularBreak) {
                    ScheduleCalendar.setEmptyMessage("No Class - \(singularBreak.reason)")
                    found = true
                    break
                }
            }
            if !found {
                day = getRegularSchedule(weekday: weekday)
            }
        }
        
        currentDay = day.blocks
        selectedDay = day.selectedDay
        
        if selectedDay < 10 {
            ScheduleCalendar.restore()
        } else if selectedDay == 10 {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your weekend")
        }
        	
        /*
        for x in LoginVC.specialSchedules { // loops through special schedule dates to see if we are in that period
            if x.key.isInThroughDate(date: date) {
                currentDay = [block]()
                ScheduleCalendar.restore()
                ScheduleCalendar.setEmptyMessage("No Class - \(x.value.reason ?? "Break")")
                completion(.success(currentDay))
                return
            }
            if x.key.lowercased() == stringDate.lowercased() {
                if !((LoginVC.blocks["l-\(weekDay.lowercased())"] as? String) ?? "").lowercased().contains("2") {
                    self.currentDay = x.value.specialSchedulesL1 
                }
                else {
                    self.currentDay = x.value.specialSchedules 
                }
                if self.currentDay.isEmpty {
                    if let urlstring = x.value.imageUrl, urlstring != "", urlstring != "N/A" {
                        ScheduleCalendar.isHidden = true
                        webView.isHidden = false
//                        scheduleImageView.image = UIImage(named: "mustachejohn")
                        if let url = URL(string: urlstring) {
                            webView.load(URLRequest(url: url))
                            if shouldEdit {
                                currentWeekday.hasImage = true
                            }
                        }
                    }
                    else {
                        ScheduleCalendar.restore()
                        ScheduleCalendar.setEmptyMessage("No Class - \(x.value.reason ?? "No Reason")")
                    }
                }
                completion(.success(self.currentDay))
                return
            }
        }
        */
        completion(.success(self.currentDay))
        return
    }
    
    func isDateInRange(date: Date, breakPeriod: Break) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        
        // Convert the startDate, endDate, and the date to compare into Date objects
        guard let start = dateFormatter.date(from: breakPeriod.startDate),
              let end = dateFormatter.date(from: breakPeriod.endDate)
        else {
            return false // Return false if any date conversion fails
        }
        
        // Check if targetDate is between start and end (inclusive)
        return (start...end).contains(date)
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setOld()
        setCurrentday(date: date, shouldEdit: false, completion: { _ in
            self.ScheduleCalendar.reloadData()
        })
    }
}
