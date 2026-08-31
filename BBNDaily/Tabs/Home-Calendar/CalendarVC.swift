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
    // HQ-628. The old version of setTimes rescheduled itself every second, forever, redoing
    // the full block resolution and a table reload each time -- even though the schedule can
    // only actually change at a block boundary (a block starting or ending), and those instants
    // are known in advance from the times resolved below. `scheduleRecomputeTimer` now fires
    // exactly once per boundary instead of 86400 times a day.
    //
    // The one thing that still needs to move every second is the countdown text ("3m left in
    // English"), so that ticks on its own `countdownTimer`, driven by `countdownTarget` /
    // `countdownPrefix` / `countdownName` -- state this function resolves once per boundary,
    // not once per second.
    private var scheduleRecomputeTimer: Timer?
    private var countdownTimer: Timer?
    private var countdownTarget: Date?
    private var countdownPrefix = ""
    private var countdownName = ""
    func setTimes(recursive: Bool) {
        var nextBoundary: Date?
        var foundCurrentBlock = false
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
                    foundCurrentBlock = true
                    countdownName = name
                    if now.isBetweenTimeFrame(date1: t, date2: t1) {
                        countdownPrefix = "Until"
                        countdownTarget = t1
                        nextBoundary = t1
                    }
                    else {
                        countdownPrefix = "left in"
                        countdownTarget = t2
                        nextBoundary = t2
                    }
                }
                i+=1
            }
            // Format the label immediately from what was just resolved, exactly once -- the
            // same as the old inline formatting, just moved into the shared helper the
            // per-second ticker below also calls.
            if foundCurrentBlock {
                updateCountdownLabel()
            }
            setOld()

            if currentWeekday.blocks.isEmpty && currentWeekday.hasImage == false { // i need to check if the active day is an image
                var z = 0
                var currDate = Date()
                let currTitle = self.navigationItem.title
                for x in LoginVC.upcomingDays {
                    if z != 0 {
                        currDate = Calendar.current.date(byAdding: .day, value: 1, to: currDate) ?? Date()
                        let currVal = "Next Day of Classes: \(x.weekdayName.capitalized)"
                        // HQ-616: hasClasses is deliberately false for a .image day, by
                        // design (notification scheduling should not fire for one, since
                        // its block times are not reliably known - see the comment on
                        // DayKind). Reusing it here for "does this day have anything
                        // worth jumping to" was wrong: an image day is a real published
                        // schedule, whether or not resolveDay could also parse structured
                        // blocks out of it, and this check made the app skip straight
                        // past it to the next day after - the "day gets skipped" was
                        // never the image failing to render, it was this scan never
                        // landing on it in the first place.
                        let isImageDay: Bool = { if case .image = x.kind { return true } else { return false } }()
                        if !x.blocks.isEmpty || isImageDay {
                            if currTitle != currVal {
                                currentWeekday.blocks = x.blocks
                                dayOverBlocks = x.blocks
                                calendar.select(currDate)
                                setCurrentday(date: currDate, shouldEdit: false, completion: { _ in
                                    self.ScheduleCalendar.reloadData()
                                })
                                self.navigationItem.title = "Next Day of Classes: \(x.weekdayName.capitalized)"
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
            // Replace whatever this instance had running before recomputing again -- otherwise
            // a boundary firing while an old countdownTimer is still ticking leaves two
            // per-second timers alive at once. A plain `recursive: false` call (pull-to-refresh,
            // one-off reloads) never reaches this branch, so it can't touch a chain it didn't
            // start.
            scheduleRecomputeTimer?.invalidate()
            countdownTimer?.invalidate()
            countdownTimer = nil
            // No boundary means no schedule for today at all (an empty calendar day): recheck
            // periodically rather than either spinning every second or never checking again.
            let fireInterval = max(1, (nextBoundary ?? Date().addingTimeInterval(60)).timeIntervalSinceNow)
            scheduleRecomputeTimer = Timer.scheduledTimer(withTimeInterval: fireInterval, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.isActive {
                    self.ScheduleCalendar.reloadData()
                }
                self.setTimes(recursive: true)
            }
            if foundCurrentBlock {
                countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    self?.updateCountdownLabel()
                }
            }
        }
        else {
            ScheduleCalendar.reloadData()
        }
    }
    private func updateCountdownLabel() {
        guard let target = countdownTarget else { return }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 2
        let interval = Date().getTimeBetween(to: target)
        self.navigationItem.title = "\(formatter.string(from: interval) ?? "0s") \(countdownPrefix) \(countdownName)"
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("isActive = false")
        isActive = false
        // The whole point of splitting these out: there is now something concrete to stop
        // when the screen isn't visible, instead of a self-rescheduling closure that kept
        // firing every second in the background regardless of `isActive`.
        scheduleRecomputeTimer?.invalidate()
        countdownTimer?.invalidate()
    }
    @objc func leaveApp() {
        print("isActive = false")
        isActive = false
        scheduleRecomputeTimer?.invalidate()
        countdownTimer?.invalidate()
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

            // The cell only offers "Press for menu" when a menu exists, but the row itself is
            // still tappable. Without this, tapping lunch on a week with no published menu
            // pushes the menu screen and immediately bounces back with "Menu not available".
            guard LoginVC.hasLunchMenu(for: realCurrentDate) else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

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
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        self.CalendarHeightConstraint.constant = bounds.height
        self.view.layoutIfNeeded()
    }
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
                    // `recursive: true`, not `false`: viewDidDisappear/leaveApp now actually
                    // stop the boundary and countdown timers (see HQ-628), so reactivating this
                    // screen has to be what restarts them, or the countdown freezes for good
                    // after the first time this tab is backgrounded or switched away from.
                    setTimes(recursive: true)
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
                return velocity.y < 0
            case .week:
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
        // The bar above is fully transparent, so bar items sit directly on the app's
        // background. That background is white in light mode, so anything tinted white
        // here is invisible. "inverse" is navy in light and white in dark, which reads
        // against both. The storyboard still tints the menu button white, so override it.
        let barItemColor = UIColor(named: "inverse") ?? .label
        self.sideMenuBtn.tintColor = barItemColor
        self.navigationItem.backBarButtonItem?.tintColor = barItemColor
        self.navigationController?.navigationBar.tintColor = barItemColor
        self.calendar.scope = .week
        // The title sits over the calendar header, which is dark in both appearances, so it
        // stays white. Only the bar items sit on the page background and needed the adaptive
        // color above.
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
        
        // The calendar reads the day from the one resolver, the same call setNotifications
        // makes, so the schedule a student is looking at and the schedule they get alerts for
        // are by construction the same answer.
        //
        // This block used to be a second copy of that logic: special days, then breaks, then
        // weekday, then the regular pattern. HQ-602 built resolveDay and pointed notifications
        // at it, but left this copy in place, so "one resolver" was only ever true of
        // notifications. The two drifted immediately -- resolveDay learned about the school
        // term and this did not, which would have meant the app suppressed summer
        // notifications while still drawing students a seven-block Wednesday.
        let resolved = resolveDay(date: date)
        currentDay = resolved.blocks
        selectedDay = resolved.weekdayIndex

        if case .image(let url) = resolved.kind {
            ScheduleCalendar.isHidden = true
            webView.isHidden = false
            if let imageUrl = URL(string: url) {
                webView.load(URLRequest(url: imageUrl))
                if shouldEdit {
                    currentWeekday.hasImage = true
                }
            }
        } else if let message = resolved.emptyMessage {
            ScheduleCalendar.restore()
            ScheduleCalendar.setEmptyMessage(message)
        } else {
            ScheduleCalendar.restore()
        }
        completion(.success(self.currentDay))
        return
    }
    
    // isDateInRange lived here and is gone. It was the calendar's own break test, and the
    // resolver's isDateInBreak is now the only one.
    //
    // It also carried a trap: `(start...end).contains(date)` builds a Swift ClosedRange, which
    // TRAPS at runtime when start is later than end. One reversed break range typed into the
    // Firestore console would have crashed the app for every student, and nothing in the app
    // would have said why. isDateInBreak compares the two bounds directly instead, so a
    // reversed range is simply not a match.

    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setOld()
        setCurrentday(date: date, shouldEdit: false, completion: { _ in
            self.ScheduleCalendar.reloadData()
        })
    }
}
