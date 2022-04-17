//
//  SecretSchedule.swift
//  BBNDaily
//
//  Created by Mike Veson on 3/22/22.
//

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import SkeletonView
import WebKit

class SecretScheduleVC: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDataSource, UITableViewDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        ScheduleCalendar.register(EditableCell.self, forCellReuseIdentifier: EditableCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        if #available(iOS 15.0, *) {
            ScheduleCalendar.sectionHeaderTopPadding = 0
        }
        addButton.setTitle("", for: .normal)
        editReasonButton.setTitle("", for: .normal)
        setCurrentday(date: Date(), completion: { [self]result in
            switch result {
            case .success(let todBlocks):
                self.currentDay = todBlocks
                calendar.delegate = self
                calendar.dataSource = self
                ScheduleCalendar.delegate = self
                ScheduleCalendar.dataSource = self
                ScheduleCalendar.reloadData()
            case .failure(_):
                print("failed :(")
            }
        })
    }
    @IBOutlet weak var editReasonButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBAction func removeAll(_ sender: Any) {
        let refreshAlert = UIAlertController(title: "Remove All Blocks", message: "Are you sure? This action cannot be undone.", preferredStyle: UIAlertController.Style.alert)
        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [self] (action: UIAlertAction!) in
              print("Handle Ok logic here")
            currentDay.lunch1Schedule = [block]()
            currentDay.lunch2Schedule = [block]()
            ScheduleCalendar.reloadData()
            uploadData()
        }))

        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
              print("Handle Cancel Logic here")
        }))

        present(refreshAlert, animated: true, completion: nil)
    }
    @IBAction func addClass(_ sender: Any) {
        TimesVC.link = self
        self.performSegue(withIdentifier: "addBlock", sender: nil)
//        let blk = block(name: blockName ?? "", startTime: startTime ?? "", endTime: endTime ?? "", block: blockType ?? "", reminderTime: reminderTime ?? "", length: 0)
//        var place = 0
//        if (lunchPref ?? "").uppercased() == "L2" {
//            for x in currentDay.lunch2Schedule {
//
//                place += 1
//            }
//        }
//        else {
//
//        }
//        uploadData()
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Lunch \(section + 1)"
    }
    @IBAction func edit(_ sender: Any) {
        if ScheduleCalendar.isEditing {
            ScheduleCalendar.isEditing = false
            editButton.setTitle("Edit", for: .normal)
        }
        else {
            ScheduleCalendar.isEditing = true
            editButton.setTitle("Done", for: .normal)
        }
    }
    @IBAction func editReason(_ sender: Any) {
        showInputDialog(title: "Edit reason",
                        subtitle: "Please enter the reason for the schedule change",
                        actionTitle: "Done",
                        cancelTitle: "Cancel",
                        inputPlaceholder: "Snow day",
                        inputKeyboardType: .numberPad, actionHandler:
                            { [self] (input:String?) in
            print("The new reason is \(input ?? "")")
            // no more code beyond here except upload
            currentDay.reason = (input ?? "")
            uploadData()
        })
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return currentDay.lunch1Schedule.count
        }
        return currentDay.lunch2Schedule.count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if indexPath.section == 0 {
                currentDay.lunch1Schedule.remove(at: indexPath.row)
            }
            else {
                currentDay.lunch2Schedule.remove(at: indexPath.row)
            }
            tableView.reloadData()
            uploadData()
        }
    }
    func uploadData() {
        // get the date, access the data, upload the data *cool emoji*
        // set it locally as well
        print("made it to upload zone")
        let formatter2 = DateFormatter()
        formatter2.dateStyle = .full
        let todaysDate = formatter2.string(from: realCurrentDate)
        LoginVC.specialSchedules["\(todaysDate)"] = currentDay.lunch2Schedule
        LoginVC.specialSchedulesL1["\(todaysDate)"] = currentDay.lunch1Schedule
        LoginVC.specialDayReasons["\(todaysDate)"] = currentDay.reason
        var lunch1 = [[String:String]]()
        var lunch2 = [[String:String]]()
        for x in currentDay.lunch2Schedule {
            lunch2.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","reminderTime":"\(x.reminderTime)","startTime":"\(x.startTime)"])
        }
        for x in currentDay.lunch1Schedule {
            lunch1.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","reminderTime":"\(x.reminderTime)","startTime":"\(x.startTime)"])
        }
        let db = Firestore.firestore()
        let currDoc = db.collection("special-schedules").document("\(todaysDate)")
        currDoc.setData(["date":"\(todaysDate)", "reason":"\(currentDay.reason)", "blocks":lunch2,"blocks-l1":lunch1])
    }
    @IBOutlet weak var addButton: UIButton!
    var currentDay = fullDay(lunch1Schedule: [block](), lunch2Schedule: [block](), reason: "")
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: EditableCell.identifier, for: indexPath) as? EditableCell else {
            fatalError()
        }
        var currentDayLunch = currentDay.lunch2Schedule
        if indexPath.section == 0 {
            currentDayLunch = currentDay.lunch1Schedule
        }
        let thisBlock = currentDayLunch[indexPath.row]
        var isLunch = false
        if thisBlock.name.lowercased().contains("lunch") {
            isLunch = true
        }
        cell.configure(with: currentDayLunch[indexPath.row], isLunch: isLunch, selectedDay: selectedDay)
        
        cell.selectionStyle = .none
        return cell
    }
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setCurrentday(date: date, completion: { _ in
            self.ScheduleCalendar.reloadData()
        })
    }
    var realCurrentDate = Date()
    var currentDate = ""
    var selectedDay = 0
    func setCurrentday(date: Date, completion: @escaping (Swift.Result<fullDay, Error>) -> Void) {
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
        
        switch weekDay {
        case "Monday":
            currentDay = fullDay(lunch1Schedule: CalendarVC.mondayL1, lunch2Schedule: CalendarVC.monday, reason: "")
            selectedDay = 0
        case "Tuesday":
            currentDay = fullDay(lunch1Schedule: CalendarVC.tuesdayL1, lunch2Schedule: CalendarVC.tuesday, reason: "")
            selectedDay = 1
        case "Wednesday":
            currentDay = fullDay(lunch1Schedule: CalendarVC.wednesdayL1, lunch2Schedule: CalendarVC.wednesday, reason: "")
            selectedDay = 2
        case "Thursday":
            currentDay = fullDay(lunch1Schedule: CalendarVC.thursdayL1, lunch2Schedule: CalendarVC.thursday, reason: "")
            selectedDay = 3
        case "Friday":
            currentDay = fullDay(lunch1Schedule: CalendarVC.fridayL1, lunch2Schedule: CalendarVC.friday, reason: "")
            selectedDay = 4
        default:
            currentDay = fullDay(lunch1Schedule: [block](), lunch2Schedule: [block](), reason: "")
            selectedDay = 10
        }
        if currentDay.lunch1Schedule.isEmpty && currentDay.lunch2Schedule.isEmpty {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your Weekend")
        }
        else {
            ScheduleCalendar.restore()
        }
        for x in CalendarVC.vacationDates {
            if stringDate.lowercased() == x.date.lowercased() {
                currentDay = fullDay(lunch1Schedule: [block](), lunch2Schedule: [block](), reason: "\(x.reason)")
                ScheduleCalendar.restore()
                ScheduleCalendar.setEmptyMessage("No Class - \(x.reason)")
                completion(.success(currentDay))
                return
            }
        }
        if date.isBetweenTimeFrame(date1: "18 Dec 2021 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Jan 2022 04:00".dateFromMultipleFormats() ?? Date()) || date.isBetweenTimeFrame(date1: "12 Mar 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "27 Mar 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = fullDay(lunch1Schedule: [block](), lunch2Schedule: [block](), reason: "Enjoy Break!")
            ScheduleCalendar.restore()
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy Break!")
            completion(.success(currentDay))
            return
        }
        
        for x in LoginVC.specialSchedules {
            if x.key.lowercased() == stringDate.lowercased() {
                let obj = LoginVC.specialSchedulesL1[x.key]
                self.currentDay.lunch2Schedule = x.value
                self.currentDay.lunch1Schedule = obj ?? [block]()
                self.currentDay.reason = "\(LoginVC.specialDayReasons[x.key] ?? "No Reason")"
                if self.currentDay.lunch2Schedule.isEmpty && self.currentDay.lunch1Schedule.isEmpty {
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
    @IBOutlet weak var ScheduleCalendar: UITableView!
    @IBOutlet weak var calendar: FSCalendar!
    static var newBlock = customBlock(isFirstLunch: false, fullBlock: block(name: "", startTime: "", endTime: "", block: "", reminderTime: "", length: 0))
}

class EditableCell: coverTableViewCell {
    override func configure(with viewModel: block, isLunch: Bool, selectedDay: Int) {
        super.configure(with: viewModel, isLunch: isLunch, selectedDay: selectedDay)
        BottomRightLabel.isHidden = false
        if viewModel.block == "N/A" {
            BottomRightLabel.text = "Tap to edit"
        }
        else {
            BottomRightLabel.text = (BottomRightLabel.text ?? "").replacingOccurrences(of: "Press for details", with: "Tap to edit")
        }
    }
}

struct fullDay {
    var lunch1Schedule: [block]
    var lunch2Schedule: [block]
    var reason: String
}

struct customBlock {
    var isFirstLunch: Bool
    var fullBlock: block
}
class BlockAndLunchVC: TextFieldVC, UITextFieldDelegate {
    @IBOutlet weak var isFirstLunch: UISwitch!
    @IBOutlet weak var blockChoice: UIButton!
    @IBAction func pressed(_ sender: Any) {
        if blockPref == "" {
            return
        }
        SecretScheduleVC.newBlock = customBlock(isFirstLunch: isFirstLunch.isOn, fullBlock: block(name: "", startTime: "", endTime: "", block: blockPref, reminderTime: "", length: 0))
        
        self.performSegue(withIdentifier: "teacher", sender: nil)
    }
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    func hideKeyboardWhenTappedAbove() {
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tap.delegate = self
    }
    var blockPref = ""
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        view.unbindToKeyboard()
        view.endEditing(true)
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 14.0, *) {
            blockChoice.menu = addMenuItems()
            blockChoice.showsMenuAsPrimaryAction = true
        } else {
            // Fallback on earlier versions
        }
        hideKeyboardWhenTappedAbove()
    }
    func addMenuItems() -> UIMenu {
        let menuItems = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: "A Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("A Block", for: .normal)
                self.blockPref = "A"
            },
            UIAction(title: "B Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("B Block", for: .normal)
                self.blockPref = "B"
            },
            UIAction(title: "C Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("C Block", for: .normal)
                self.blockPref = "C"
            },
            UIAction(title: "D Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("D Block", for: .normal)
                self.blockPref = "D"
            },
            UIAction(title: "E Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("E Block", for: .normal)
                self.blockPref = "E"
            },
            UIAction(title: "F Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("F Block", for: .normal)
                self.blockPref = "F"
            },
            UIAction(title: "G Block", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("G Block", for: .normal)
                self.blockPref = "G"
            },
            UIAction(title: "N/A", image: UIImage(systemName: "house")) { action in
                self.blockChoice.setTitle("N/A", for: .normal)
                self.blockPref = "N/A"
            }
        ])
        return menuItems
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        TextField.resignFirstResponder()
        dismissKeyboard()
        return true
    }
    @IBOutlet weak var TextField: UITextField!
    
}
class BlockNameVC: TextFieldVC, UITextFieldDelegate {
    @IBAction func pressed(_ sender: Any) {
        guard var text = TextField.text, text.trimmingCharacters(in: .whitespacesAndNewlines) != "", !text.contains("~"), !text.contains("/") else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("Please complete fields! (Don't use any ~ or /)")
            return
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        SecretScheduleVC.newBlock.fullBlock.name = text
        self.performSegue(withIdentifier: "room", sender: nil)
    }
    func hideKeyboardWhenTappedAbove() {
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tap.delegate = self
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        TextField.resignFirstResponder()
        dismissKeyboard()
        return true
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.location(in: view).y > TextField.frame.origin.y && touch.location(in: view).y < TextField.frame.maxY {
            return false
        }
        view.unbindToKeyboard()
        view.endEditing(true)
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAbove()
        TextField.delegate = self
    }
    @IBOutlet weak var TextField: UITextField!
}

class TimesVC: TextFieldVC, UITextFieldDelegate {
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var reminderPicker: UIDatePicker!
    @IBOutlet weak var startPicker: UIDatePicker!
    static var link: SecretScheduleVC!
    @IBAction func pressed(_ sender: Any) {
        let formatter2 = DateFormatter()
        formatter2.dateStyle = .none
        formatter2.timeStyle = .short
        var reminderTime = formatter2.string(from: reminderPicker.date).lowercased().replacingOccurrences(of: " ", with: "")
        var startTime = formatter2.string(from: startPicker.date).lowercased().replacingOccurrences(of: " ", with: "")
        var endTime = formatter2.string(from: datePicker.date).lowercased().replacingOccurrences(of: " ", with: "")
        if reminderTime.prefix(1) != "1" || reminderTime.prefix(2) == "1:" {
            reminderTime = "0\(reminderTime)"
        }
        if startTime.prefix(1) != "1" || startTime.prefix(2) == "1:" {
            startTime = "0\(startTime)"
        }
        if endTime.prefix(1) != "1" || endTime.prefix(2) == "1:" {
            endTime = "0\(endTime)"
        }
        
        SecretScheduleVC.newBlock.fullBlock.reminderTime = reminderTime
        SecretScheduleVC.newBlock.fullBlock.startTime = startTime
        SecretScheduleVC.newBlock.fullBlock.endTime = endTime
        let blk = SecretScheduleVC.newBlock
        if blk.isFirstLunch {
            TimesVC.link.currentDay.lunch1Schedule.append(blk.fullBlock)
        }
        else {
            TimesVC.link.currentDay.lunch2Schedule.append(blk.fullBlock)
        }
        TimesVC.link.ScheduleCalendar.restore()
        TimesVC.link.ScheduleCalendar.reloadData()
        TimesVC.link.uploadData()
        self.dismiss(animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
