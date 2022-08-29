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


class MapScheduleVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBAction func comingSoon(_ sender: Any) {
        let alert = UIAlertController(title: "Bus Tracking", message: "Bus Tracking will come soon to a future update! (AKA once someone actually puts a tracker on the bus) First person to put a tracker on the bus gets Knight Life credit!", preferredStyle: .alert)

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
        if segmentedControl.selectedSegmentIndex == 0 {
            busSchedule = fourthLotSchedule
        }
        else {
            busSchedule = harvardSquareSchedule
        }
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
        let sectionLabel: UILabel = {
            let label = UILabel()
            label.textColor = UIColor(named: "inverse")
            label.font = .systemFont(ofSize: 15, weight: .medium)
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
    var fourthLotSchedule = [
        BusSection(title: "AM Shuttle", buses: [Bus(title: "4th Lot to Upper School", times:
                                                        [
                                                            Time(departure: "6:40 AM", arrival: "6:45 AM", weekDays: "M/W/Th/F"),
                                                            Time(departure: "6:55 AM", arrival: "7:00 AM"),
                                                            Time(departure: "7:10 AM", arrival: "7:15 AM"),
                                                            Time(departure: "7:25 AM", arrival: "7:30 AM"),
                                                            Time(departure: "7:40 AM", arrival: "7:45 AM"),
                                                            Time(departure: "7:55 AM", arrival: "8:00 AM"),
                                                            Time(departure: "8:10 AM", arrival: "8:15 AM"),
                                                            Time(departure: "8:25 AM", arrival: "8:30 AM"),
                                                            Time(departure: "8:40 AM", arrival: "8:45 AM", weekDays: "Tuesday")
                                                        ]
                                                   )]),
        BusSection(title: "Midday Shuttle", buses: [Bus(title: "Upper School to 4th Lot", times:
                                                            [
                                                                Time(departure: "11:30 AM", arrival: "11:35 AM"),
                                                                Time(departure: "11:45 AM", arrival: "11:50 AM"),
                                                                Time(departure: "12:00 PM", arrival: "12:05 PM"),
                                                                Time(departure: "12:20 PM", arrival: "12:25 PM"),
                                                                Time(departure: "12:35 PM", arrival: "12:40 PM"),
                                                                Time(departure: "12:50 PM", arrival: "12:55 PM"),
                                                                Time(departure: "1:05 PM", arrival: "1:10 PM"),
                                                                Time(departure: "1:20 PM", arrival: "1:25 PM"),
                                                                Time(departure: "1:35 PM", arrival: "1:40 PM"),
                                                                Time(departure: "1:50 PM", arrival: "1:55 PM")
                                                            ]
                                                       ),
                                                    Bus(title: "4th Lot to Upper School", times:
                                                            [
                                                                Time(departure: "11:50 AM", arrival: "11:55 AM"),
                                                                Time(departure: "12:05 PM", arrival: "12:10 PM"),
                                                                Time(departure: "12:25 PM", arrival: "12:30 PM"),
                                                                Time(departure: "12:40 PM", arrival: "12:45 PM"),
                                                                Time(departure: "12:55 PM", arrival: "1:00 PM"),
                                                                Time(departure: "1:10 PM", arrival: "1:15 PM"),
                                                                Time(departure: "1:25 PM", arrival: "1:30 PM"),
                                                                Time(departure: "1:40 PM", arrival: "1:45 PM"),
                                                                Time(departure: "1:55 PM", arrival: "2:00 PM")
                                                            ]
                                                           )]),
        BusSection(title: "PM Shuttle", buses: [Bus(title: "Upper School to 4th Lot", times:
                                                        [
                                                            Time(departure: "3:00 PM", arrival: "3:05 PM"),
                                                            Time(departure: "3:15 PM", arrival: "3:20 PM"),
                                                            Time(departure: "3:30 PM", arrival: "3:35 PM"),
                                                            Time(departure: "3:45 PM", arrival: "3:50 PM"),
                                                            Time(departure: "4:00 PM", arrival: "4:05 PM"),
                                                            Time(departure: "4:15 PM", arrival: "4:20 PM"),
                                                            Time(departure: "4:30 PM", arrival: "4:35 PM"),
                                                            Time(departure: "4:45 PM", arrival: "4:50 PM"),
                                                            Time(departure: "5:00 PM", arrival: "5:05 PM"),
                                                            Time(departure: "5:15 PM", arrival: "5:20 PM"),
                                                            Time(departure: "5:30 PM", arrival: "5:35 PM"),
                                                            Time(departure: "6:15 PM", arrival: "6:20 PM"),
                                                        ])])]
    var harvardSquareSchedule = [BusSection(title: "AM Shuttle", buses: [Bus(title: "Harvard Square to Upper School", times: [Time(departure: "6:40 AM", arrival: "6:48 AM", weekDays: "M/W/Th/F"), Time(departure: "7:00 AM", arrival: "7:08 AM"), Time(departure: "7:20 AM", arrival: "7:28 AM"), Time(departure: "7:40 AM", arrival: "7:48 AM", arrivalTwo: "7:56 AM"), Time(departure: "8:05 AM", arrival: "8:13 AM", weekDays: "Tuesday", arrivalTwo: "8:21 AM"), Time(departure: "8:30 AM", arrival: "8:38 AM", weekDays: "Tuesday", arrivalTwo: "8:46 AM")])]), BusSection(title: "PM Shuttle", buses: [Bus(title: "Upper School to Harvard Square", times: [Time(departure: "2:00 PM", arrival: "2:08 PM"), Time(departure: "2:20 PM", arrival: "2:28 PM"), Time(departure: "3:30 PM", arrival: "3:38 PM"), Time(departure: "3:50 PM", arrival: "3:58 PM"), Time(departure: "4:10 PM", arrival: "4:18 PM"), Time(departure: "4:30 PM", arrival: "4:38 PM"), Time(departure: "4:50 PM", arrival: "4:58 PM"), Time(departure: "5:10 PM", arrival: "5:18 PM")])])]
    override func viewDidLoad() {
        super.viewDidLoad()
        busSchedule = fourthLotSchedule
        view.backgroundColor = UIColor(named: "background")
        tableView.register(busTimesTableViewCell.self, forCellReuseIdentifier: busTimesTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
    }
}


class BusSection: NSObject {
    var title: String
    var buses: [Bus]
    var isOpened = false
    init(title: String, buses: [Bus]) {
        self.title = title
        self.buses = buses
    }
}

struct Bus {
    let title: String
    let times: [Time]
}

class Time: NSObject {
    var departure: String
    var arrival: String
    var weekDays: String?
    var arrivalTwo: String?
    init(departure: String, arrival: String, weekDays: String) {
        self.departure = departure
        self.arrival = arrival
        self.weekDays = weekDays
    }
    init(departure: String, arrival: String) {
        self.departure = departure
        self.arrival = arrival
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
}

class busTimesTableViewCell: UITableViewCell {
    static let identifier = "busTimesTableViewCell"
    
    let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.minimumScaleFactor = 0.5
        label.text = "Departs: "
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let BlockLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.text = "Arrival: "
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let RightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(named: "inverse")
        label.minimumScaleFactor = 0.8
        label.textAlignment = .right
        label.text = ""
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let BottomRightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
        label.text = ""
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    let arrivalTwoLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        label.minimumScaleFactor = 0.8
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
        TitleLabel.text?.append(viewModel.departure)
        if let weekdays = viewModel.weekDays {
            RightLabel.text = weekdays
        }
        else {
            RightLabel.text = "All Weekdays"
        }
        if let arrivalTwo = viewModel.arrivalTwo {
            
            BlockLabel.text = "Upper School Arrival: \(arrivalTwo)"
            arrivalTwoLabel.text = "Middle School Arrival: \(viewModel.arrival)"
        }
        else {
            arrivalTwoLabel.isHidden = true
            BlockLabel.text?.append(viewModel.arrival)
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
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "\(titleTime): \(viewModel.title)"
        view.backgroundColor = UIColor(named: "background")
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.register(busTimesTableViewCell.self, forCellReuseIdentifier: busTimesTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
    }
}
