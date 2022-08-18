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

class CalendarVC: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, WKNavigationDelegate {
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
                let currTitle = self.navigationItem.title
                for x in LoginVC.upcomingDays {
                    if z != 0 {
                        currDate = Calendar.current.date(byAdding: .day, value: 1, to: currDate) ?? Date()
                        let currVal = "Next Day of Classes: \(x.weekday.capitalized)"
                        if !x.blocks.isEmpty {
                            if currTitle != currVal {
                                currentWeekday = x.blocks
                                dayOverBlocks = x.blocks
                                calendar.select(currDate)
                                setCurrentday(date: currDate, completion: { _ in
                                    self.ScheduleCalendar.reloadData()
                                })
                                self.navigationItem.title = "Next Day of Classes: \(x.weekday.capitalized)"
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
                    print("reloading...")
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
        for x in currentWeekday {
            let big = getReturnDates(currBlock: x)
            let t2 = big[3]
            if currentDate == stringDate {
                if Date() > t2 {
                    currentWeekday.remove(at: y)
                    y-=1
                }
                if currentBlock.startTime == x.startTime && y == currentWeekday.count {
                    currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n")
                    self.navigationItem.title = "My Schedule"
                }
            }
            y+=1
        }
        if currentWeekday.isEmpty {
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
    var currentWeekday = [block(name: "", startTime: "", endTime: "", block: "")]
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
                        currentDay = currentWeekday
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
        print("view WILL appear -> reloading the page")
        isActive = true
        reloadPage()
        v+=1
    }
    @objc func screenReopened() {
        isActive = true
        print("screen has reopened -> reloading the page")
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
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "CalendarVC")
                var viewcontrollers = self.navigationController?.viewControllers ?? [UIViewController]()
                if !viewcontrollers.isEmpty {
                    viewcontrollers.removeAll()
                }
                viewcontrollers.append(vc)
                self.navigationController?.setViewControllers(viewcontrollers, animated: false)
            }
            else {
                setCurrentday(date: realCurrentDate, completion: { [self]_ in
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
//        print("view DID load")
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
        setCurrentday(date: Date(), completion: { [self]result in
            switch result {
            case .success(let todBlocks):
                self.currentWeekday = todBlocks
                CalendarVC.todayBlocks = todBlocks
                calendar.delegate = self
                calendar.dataSource = self
                ScheduleCalendar.delegate = self
                ScheduleCalendar.dataSource = self
//                self.configureWatchKitSession()
                setNotifications()
                ScheduleCalendar.reloadData()
                setTimes(recursive: true)
            case .failure(_):
                print("failed :(")
            }
        })
    }
//    var session: WCSession?
//    func setWatchClasses(todBlocks: [block]) {
//        watchClasses = [WatchClass]()
//        for x in todBlocks {
//            let dateformatter = DateFormatter()
//            dateformatter.dateFormat = "h:mm a"
//            dateformatter.amSymbol = "AM"
//            dateformatter.pmSymbol = "PM"
//            let dates = getReturnDates(currBlock: x)
//            let t2 = dates[1]
//            let t3 = dates[2]
//
//            var className: String?
//            if x.block != "N/A" {
//                className = LoginVC.blocks[x.block] as? String
//                if className == "" {
//                    className = "[\(x.block) Class]"
//                }
//                if (className ?? "").contains("~") {
//                    let array = (className ?? "").getValues()
//                    className = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
//                    if !(LoginVC.classMeetingDays["\(x.block.lowercased())"]?[selectedDay] ?? true) {
//                        className = "\(x.name)"
//                    }
//                }
//            }
//            else {
//                className = "\(x.name)"
//            }
//            watchClasses.append(WatchClass(Title: (className ?? ""), StartTime: "\(dateformatter.string(from: t3))", EndTime: "\(dateformatter.string(from: t2))"))
//        }
////        let data2: [String: Any] = ["classes": watchClasses as Any]
////        session!.sendMessage(data2, replyHandler: nil, errorHandler: { error in
////            print("on't work \(error)")
////        })
//        if let validSession = self.session, validSession.isReachable {//5.1
//            print("success!")
//            let data: [String: Any] = ["classes": watchClasses as Any]
//            validSession.sendMessage(data, replyHandler: nil, errorHandler: nil)
//        }
//        else {
//            print("FAILED AGAIn")
//        }
//    }
    
    
//    func configureWatchKitSession() {
//
//        if WCSession.isSupported() {//4.1
//            print("session activated??")
//          session = WCSession.default//4.2
//          session?.delegate = self//4.3
//          session?.activate()//4.4
//        }
//        else {
//            print("SHIT DON WORK")
//        }
//      }
//    @IBOutlet weak var scheduleImageView: UIImageView!
    static let vacationDates = [
        NoSchoolDay(date: "Monday, September 6, 2021", reason: "Labor Day"),
        NoSchoolDay(date: "Tuesday, September 7, 2021", reason: "Rosh Hashanah"),
        NoSchoolDay(date: "Thursday, September 16, 2021", reason: "Yom Kippur"),
        NoSchoolDay(date: "Monday, October 11, 2021", reason: "Indigenous Peoples Day"),
        NoSchoolDay(date: "Tuesday, October 12, 2021", reason: "Professional Day"),
        NoSchoolDay(date: "Thursday, November 11, 2021", reason: "Veterans Day"),
        NoSchoolDay(date: "Thursday, November 25, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Friday, November 26, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Monday, January 17, 2022", reason: "MLK Jr. Day"),
        NoSchoolDay(date: "Monday, February 21, 2022", reason: "Presidents Day"),
        NoSchoolDay(date: "Tuesday, February 22, 2022", reason: "Professional Day"),
        NoSchoolDay(date: "Monday, April 18, 2022", reason: "Patriots Day"),
        NoSchoolDay(date: "Monday, May 30, 2022", reason: "Memorial Day")
    ]
    var selectedDay = 0
    var realCurrentDate = Date()
    func setCurrentday(date: Date, completion: @escaping (Swift.Result<[block], Error>) -> Void) {
        ScheduleCalendar.isHidden = false
        webView.isHidden = true
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
        let lunchDays = getLunchDays(weekDay: String(weekDay))
        currentDay = lunchDays.blocks
        selectedDay = lunchDays.selectedDay
        if currentDay.isEmpty {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your Weekend")
        }
        else {
            ScheduleCalendar.restore()
        }
//        if date.isBetweenTimeFrame(date1: "11 Jun 2022 04:00".startOrEndDate(isStart: true) ?? Date(), date2: "02 Sep 2022 04:00".startOrEndDate(isStart: false) ?? Date()) {
//            currentDay = [block]()
//            ScheduleCalendar.restore()
//            ScheduleCalendar.setEmptyMessage("No Class - Summer Break!")
//            completion(.success(currentDay))
//            return
//        }
        	
        for x in LoginVC.specialSchedules {
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
                        }
//                        scheduleImageView.loadImageUsingCacheWithUrlString(urlstring: urlstring, completion: { _ in
//                        })
                        // check for image
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
