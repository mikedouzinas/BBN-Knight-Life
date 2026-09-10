//
//  MapScheduleVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 8/22/22.
//

import UIKit
import ProgressHUD
import InitialsImageView
import SafariServices
import SkeletonView


class BusScheduleVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBAction func comingSoon(_ sender: Any) {
        let alert = UIAlertController(title: "Bus Tracking", message: "Bus Tracking will come soon to a future update! (AKA once someone actually puts trackers on the buses!)", preferredStyle: .alert)

               // add an action (button)
               alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

               // show the alert
               self.present(alert, animated: true, completion: nil)
    }
    @IBAction func callBus(_ sender: Any) {
        guard let number = URL(string: "tel://" + "\(LoginVC.busNumber)") else { return }
        UIApplication.shared.open(number)
    }
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBAction func segmentedControlDidChange(_ sender: UISegmentedControl) {
        applySelectedSegment()
    }

    // HQ-1042: the one place that decides what the table shows. Both the segmented control
    // and the Firestore refresh route through here, so a schedule that arrives while the
    // student is looking at the other segment cannot leave the two out of step.
    //
    // Empty sections are dropped rather than rendered. A BusSection with no buses draws a
    // header with nothing under it, which is what the "Home" segment has looked like since
    // 2024-09-14 (e2dd6c4) and reads as a broken app rather than as a route BB&N does not
    // publish.
    func applySelectedSegment() {
        let selected: [BusSection]
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            selected = shuttleSchedule
        case 1:
            selected = homeSchedule
        default:
            selected = [BusSection]()
        }
        busSchedule = selected.filter { !$0.buses.isEmpty }
        emptyLabel.isHidden = !busSchedule.isEmpty
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sect = busSchedule[section]
        return sect.buses.count
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return busSchedule[section].title
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let sect = busSchedule[indexPath.section]
        // Two lines and a shrink-to-fit floor, so a long route name wraps instead of running
        // off the edge. The titles are short now, but they arrive from Firestore and whoever
        // types the next one cannot be expected to know the width of this label.
        let sectionLabel: UILabel = {
            let label = UILabel()
            label.textColor = UIColor(named: "inverse")
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.numberOfLines = 2
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.75
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        } ()
        cell.addSubview(sectionLabel)
        sectionLabel.text = "\(sect.buses[indexPath.row].title)"
        sectionLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
        sectionLabel.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: 5).isActive = true
        sectionLabel.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -5).isActive = true
        cell.backgroundColor = UIColor(named: "background")
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return busSchedule.count
    }
    
    @IBOutlet weak var tableView: UITableView!
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 35
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let popup = BusTimesVC()
        popup.viewModel = busSchedule[indexPath.section].buses[indexPath.row]
        popup.titleTime = busSchedule[indexPath.section].title
        show(popup, sender: nil)
    }
    
    public var tasks = [SchoolTask]()
    var busSchedule = [BusSection]()
    var shuttleSchedule = BusSection.defaultShuttleSchedule
    var homeSchedule = BusSection.defaultHomeSchedule

    // HQ-1042: shown when the selected segment has no buses at all, in place of the blank
    // headers that were there before. It says the times are missing rather than implying
    // there are no buses, because those are different facts and only one of them is known.
    let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "No routes listed yet.\nCheck with the front office."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = UIColor(named: "lightGray")
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        tableView.register(busTimesTableViewCell.self, forCellReuseIdentifier: busTimesTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self

        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor, constant: 24),
            emptyLabel.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor, constant: -24)
        ])

        applySelectedSegment()

        // HQ-1042: refresh from Firestore. The table already shows the bundled schedule, so
        // this is a silent update when the times have changed, not a loading state anyone
        // waits on. Same shape as fetchSideMenuPublications (HQ-661).
        fetchBusSchedules { [weak self] shuttle, home in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.shuttleSchedule = shuttle
                self.homeSchedule = home
                self.applySelectedSegment()
            }
        }
    }
}

// HQ-1042: the schedule that ships inside the app. It is both the instant-display default,
// so the tab is never empty while Firestore is still loading, and the fallback when the
// document does not exist, is empty, or fails to read - so a school that has never touched
// the new collection sees exactly what it saw before, never a blank tab.
//
// Editing these literals is no longer how a bus time gets changed. Publish to
// busSchedule/shuttle or busSchedule/home instead; that reaches students who already have
// the app, which a code change cannot do without an App Store release.
extension BusSection {
    // BB&N Shuttle Service, Fall/Winter 2026-27. South Station, Harvard Square, Upper School
    // and Grove St. Rows are ordered by departure time, because a student reads this looking
    // for the next bus rather than looking for a particular service.
    static let defaultShuttleSchedule: [BusSection] = [
        BusSection(title: "Grove St", buses: [
            Bus(title: "To Upper School", times: [
                Time(departure: "6:40 AM", arrival: "6:45 AM"),
                Time(departure: "6:55 AM", arrival: "7:10 AM"),
                Time(departure: "7:20 AM", arrival: "7:35 AM"),
                Time(departure: "7:45 AM", arrival: "8:00 AM"),
                Time(departure: "8:10 AM", arrival: "8:25 AM"),
                Time(departure: "8:35 AM", arrival: "8:50 AM"),
                Time(departure: "9:00 AM", arrival: "9:15 AM"),
                Time(departure: "9:30 AM", arrival: "9:45 AM"),
                Time(departure: "10:30 AM", arrival: "10:45 AM")
            ]),
            Bus(title: "To Grove St", times: [
                Time(departure: "12:00 PM", arrival: "12:15 PM"),
                Time(departure: "12:15 PM", arrival: "12:30 PM", weekDays: "Wednesday"),
                Time(departure: "12:45 PM", arrival: "1:00 PM", weekDays: "Wednesday"),
                Time(departure: "1:00 PM", arrival: "1:15 PM"),
                Time(departure: "1:15 PM", arrival: "1:30 PM", weekDays: "Wednesday"),
                Time(departure: "1:30 PM", arrival: "1:45 PM"),
                Time(departure: "1:50 PM", arrival: "2:05 PM", weekDays: "Wednesday"),
                Time(departure: "2:15 PM", arrival: "2:30 PM", weekDays: "Wednesday"),
                Time(departure: "2:45 PM", arrival: "3:00 PM", weekDays: "Wed/Fri"),
                Time(departure: "3:30 PM", arrival: "3:45 PM"),
                Time(departure: "3:50 PM", arrival: "4:05 PM"),
                Time(departure: "4:15 PM", arrival: "4:30 PM"),
                Time(departure: "5:00 PM", arrival: "5:15 PM"),
                Time(departure: "5:30 PM", arrival: "5:45 PM"),
                Time(departure: "6:00 PM", arrival: "6:15 PM"),
                Time(departure: "6:30 PM", arrival: "6:45 PM")
            ])
        ]),
        BusSection(title: "South Station & Harvard Square", buses: [
            // South Station is Atlantic Ave & Essex St. Harvard Square is 16 Eliot Street.
            // The 7:50 AM does not stop at Harvard Square, which is why it names its arrival
            // rather than carrying a second one.
            Bus(title: "To Upper School", times: [
                Time(departure: "6:50 AM", departureSpot: "South Station", arrival: "7:10 AM", arrivalSpot: "Harvard Square", arrivalTwo: "7:20 AM", arrivalTwoSpot: "Upper School"),
                Time(departure: "7:50 AM", departureSpot: "South Station", arrival: "8:12 AM", arrivalSpot: "Upper School")
            ]),
            // BB&N marks every arrival on this route as approximate: "due to heavy traffic in
            // Cambridge drop-off times can fluctuate." It rides in `note`, under the times,
            // rather than in the title.
            Bus(title: "From Upper School", note: "Arrival times are approximate. Heavy traffic in Cambridge means drop-off times can fluctuate. The 7:00 PM Wednesday run is on a trial basis.", times: [
                Time(departure: "1:50 PM", departureSpot: "Upper School", arrival: "2:15 PM", arrivalSpot: "Harvard Square", arrivalTwo: "2:45 PM", arrivalTwoSpot: "South Station", weekDays: "Wednesday"),
                Time(departure: "3:40 PM", departureSpot: "Upper School", arrival: "3:55 PM", arrivalSpot: "Harvard Square", arrivalTwo: "4:25 PM", arrivalTwoSpot: "South Station", weekDays: "M/Tu/Th/F"),
                Time(departure: "5:30 PM", departureSpot: "Upper School", arrival: "5:45 PM", arrivalSpot: "Harvard Square", arrivalTwo: "6:15 PM", arrivalTwoSpot: "South Station"),
                Time(departure: "6:30 PM", departureSpot: "Upper School", arrival: "6:45 PM", arrivalSpot: "Harvard Square", arrivalTwo: "7:15 PM", arrivalTwoSpot: "South Station", weekDays: "M/Tu/Th/F"),
                Time(departure: "7:00 PM", departureSpot: "Upper School", arrival: "7:15 PM", arrivalSpot: "Harvard Square", arrivalTwo: "7:45 PM", arrivalTwoSpot: "South Station", weekDays: "Wednesday (trial)")
            ])
        ])
    ]
    // Empty since e2dd6c4 (2024-09-14), which replaced a working PM shuttle list with these
    // two headers and never filled them in. Left empty on purpose rather than restored from
    // that commit: those times are from 2022 and publishing them as current is how somebody
    // misses a bus. The real ones go in busSchedule/home.
    static let defaultHomeSchedule: [BusSection] = []
}


class BusSection: NSObject {
    var title: String
    var buses: [Bus]
    var isOpened = false
    init(title: String, buses: [Bus]) {
        self.title = title
        self.buses = buses
    }

    // HQ-1042. A section with no readable buses is dropped rather than rendered, because a
    // header with nothing under it is exactly the failure this ticket exists to remove.
    convenience init?(dict: [String: Any]) {
        guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
        let buses = (dict["buses"] as? [[String: Any]] ?? []).compactMap { Bus(dict: $0) }
        guard !buses.isEmpty else { return nil }
        self.init(title: title, buses: buses)
    }
}

struct Bus {
    let title: String
    let times: [Time]

    // A caveat about the whole route, shown under the times rather than inside the title.
    // HQ-1050: "(arrivals approximate)" started life appended to the title, which made the
    // route name unreadable in the list and produced a navigation title of
    // "South Station & Harvard Square: Upper School to Harvard Square & South Station
    // (arrivals approximate)". A title is a name; a caveat is not part of a name.
    let note: String?

    // `note` sits before `times` so a caller reads the caveat next to the name rather than
    // after a forty-line array. Defaulted, so every existing Bus(title:times:) call still
    // compiles unchanged.
    init(title: String, note: String? = nil, times: [Time]) {
        self.title = title
        self.times = times
        self.note = note
    }

    init?(dict: [String: Any]) {
        guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
        let times = (dict["times"] as? [[String: Any]] ?? []).compactMap { Time(dict: $0) }
        guard !times.isEmpty else { return nil }
        self.init(
            title: title,
            note: (dict["note"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            times: times
        )
    }
}

class Time: NSObject {
    var departure: String
    var departureSpot: String?
    var arrival: String
    var arrivalSpot: String?
    var weekDays: String?
    var arrivalTwo: String?
    var arrivalTwoSpot: String?
    init(departure: String, arrival: String) {
        self.departure = departure
        self.arrival = arrival
    }
    init(departure: String, arrival: String, weekDays: String) {
        self.departure = departure
        self.arrival = arrival
        self.weekDays = weekDays
    }
    init(departure: String, departureSpot: String?, arrival: String, arrivalSpot: String) {
        self.departure = departure
        self.departureSpot = departureSpot
        self.arrival = arrival
        self.arrivalSpot = arrivalSpot
    }
    init(departure: String, departureSpot: String?, arrival: String, arrivalSpot: String, weekDays: String) {
        self.departure = departure
        self.departureSpot = departureSpot
        self.arrival = arrival
        self.arrivalSpot = arrivalSpot
        self.weekDays = weekDays
    }
    init(departure: String, arrival: String, arrivalTwo: String) {
        self.departure = departure
        self.arrival = arrival
        self.arrivalTwo = arrivalTwo
    }
    init(departure: String, arrival: String, weekDays: String, arrivalTwo: String) {
        self.departure = departure
        self.arrival = arrival
        self.arrivalTwo = arrivalTwo
        self.weekDays = weekDays
    }
    init(departure: String, departureSpot: String?, arrival: String, arrivalSpot: String, arrivalTwo: String, arrivalTwoSpot: String) {
        self.departure = departure
        self.departureSpot = departureSpot
        self.arrival = arrival
        self.arrivalSpot = arrivalSpot
        self.arrivalTwo = arrivalTwo
        self.arrivalTwoSpot = arrivalTwoSpot
    }
    init(departure: String, departureSpot: String?, arrival: String, arrivalSpot: String, arrivalTwo: String, arrivalTwoSpot: String, weekDays: String) {
        self.departure = departure
        self.departureSpot = departureSpot
        self.arrival = arrival
        self.arrivalSpot = arrivalSpot
        self.arrivalTwo = arrivalTwo
        self.arrivalTwoSpot = arrivalTwoSpot
        self.weekDays = weekDays
    }

    // HQ-1042. Deliberately a separate labelled init rather than an all-optional memberwise
    // one: an init whose parameters all had defaults would be ambiguous with the two-argument
    // init above at every existing call site in the bundled schedule.
    //
    // departure and arrival are required because a row missing either shows a student a bus
    // with no time on it. Everything else is decoration and defaults to absent.
    init?(dict: [String: Any]) {
        guard let departure = dict["departure"] as? String, !departure.isEmpty,
              let arrival = dict["arrival"] as? String, !arrival.isEmpty else { return nil }
        self.departure = departure
        self.arrival = arrival
        super.init()
        self.departureSpot = (dict["departureSpot"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.arrivalSpot = (dict["arrivalSpot"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.weekDays = (dict["weekDays"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        // Both halves of the second stop or neither. A time with an arrivalTwo and no
        // arrivalTwoSpot renders the second leg as a blank line in the cell.
        if let two = (dict["arrivalTwo"] as? String).flatMap({ $0.isEmpty ? nil : $0 }),
           let twoSpot = (dict["arrivalTwoSpot"] as? String).flatMap({ $0.isEmpty ? nil : $0 }) {
            self.arrivalTwo = two
            self.arrivalTwoSpot = twoSpot
        }
    }
}

class busTimesTableViewCell: UITableViewCell {
    static let identifier = "busTimesTableViewCell"
    
    let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 1
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.text = "Departs: "
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let BlockLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.text = "Arrival: "
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let RightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(named: "inverse")
        label.minimumScaleFactor = 0.8
        label.textAlignment = .right
        label.adjustsFontSizeToFitWidth = true
        label.text = ""
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let BottomRightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.text = ""
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let arrivalTwoLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.text = ""
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    public let backView: UIView = {
        let backview = UIView()
        backview.translatesAutoresizingMaskIntoConstraints = false
        backview.isSkeletonable = true
        backview.layer.cornerRadius = 6
        backview.layer.masksToBounds = true
        backview.skeletonCornerRadius = 8
        backview.backgroundColor = .clear
        return backview
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(backView)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(BlockLabel)
        contentView.addSubview(RightLabel)
        contentView.addSubview(BottomRightLabel)
        contentView.addSubview(arrivalTwoLabel)
        contentView.backgroundColor = UIColor(named: "background")
        backgroundColor = UIColor(named: "background")
        
        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    internal var backViewLeftConstraint = NSLayoutConstraint()
    var titleCenterConstraint = NSLayoutConstraint()
    var blockCenterConstraint = NSLayoutConstraint()
    internal var rightLabelWidthConstraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        
        titleCenterConstraint = TitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7.5)
        titleCenterConstraint.isActive = true
        
        backViewLeftConstraint = backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5)
        backViewLeftConstraint.isActive = true
        backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: RightLabel.leftAnchor, constant: -2).isActive = true
        
        blockCenterConstraint = BlockLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7.5)
        blockCenterConstraint.isActive = true
        
        BlockLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        
        arrivalTwoLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        arrivalTwoLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        
        rightLabelWidthConstraint = RightLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        rightLabelWidthConstraint.isActive = true
        RightLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7.5).isActive = true
        RightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        
        BottomRightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BottomRightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func superLayoutSubviews() {
        super.layoutSubviews()
    }
    func configure(with viewModel: Time) {
        TitleLabel.text = "Departs: \(viewModel.departure)"
        BlockLabel.text = "Arrival: "
//        TitleLabel.text?.append(viewModel.departure)
        if let departureSpot = viewModel.departureSpot {
            TitleLabel.text = "\(departureSpot) Departure: \(viewModel.departure)"
        }
        if let arrivalSpot = viewModel.arrivalSpot {
            BlockLabel.text = "\(arrivalSpot) Arrival: "
        }
        BlockLabel.text?.append(contentsOf: "\(viewModel.arrival)")
        if let arrivalTwoSpot = viewModel.arrivalTwoSpot, let arrivalTwo = viewModel.arrivalTwo {
            arrivalTwoLabel.text = BlockLabel.text
            BlockLabel.text = "\(arrivalTwoSpot) Arrival: \(arrivalTwo)"
        }
        else {
            arrivalTwoLabel.isHidden = true
        }
        if let weekdays = viewModel.weekDays {
            RightLabel.text = weekdays
        }
        else {
            RightLabel.text = "All Weekdays"
        }
    }
}


class BusTimesVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.times.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sect = viewModel.times[indexPath.row]
        if let _ = sect.arrivalTwo {
            return 70
        }
        return 50
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: busTimesTableViewCell.identifier, for: indexPath) as? busTimesTableViewCell else {
            fatalError()
        }
        cell.configure(with: viewModel.times[indexPath.row])
        return cell
    }
    private var tableView = UITableView()
    var viewModel: Bus!
    var titleTime = ""

    // The route caveat, under the times. A footer is where a caveat belongs: it is readable,
    // it scrolls with the times it qualifies, and it costs the title nothing.
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return viewModel.note
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The route name alone. This used to prepend the section title, which is the screen the
        // student just tapped through from, so it said something they already knew at the cost
        // of truncating the thing they came for. HQ-1050.
        self.title = viewModel.title
        view.backgroundColor = UIColor(named: "background")
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.register(busTimesTableViewCell.self, forCellReuseIdentifier: busTimesTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        if let tabBarController = tabBarController {
            self.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: tabBarController.tabBar.frame.height, right: 0.0)
        }
        tableView.delegate = self
        tableView.dataSource = self
    }
}
