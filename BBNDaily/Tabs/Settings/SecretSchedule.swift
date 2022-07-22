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
    @IBAction func openImage(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ImageVC") as? UINavigationController
        let vc2 = vc?.children[0] as? ImageVC
        vc2?.link = self
        guard let vc = vc else {
            return
        }
        present(vc, animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        ScheduleCalendar.register(EditableCell.self, forCellReuseIdentifier: EditableCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        if #available(iOS 15.0, *) {
            ScheduleCalendar.sectionHeaderTopPadding = 0
        }
        addButton.setTitle("", for: .normal)
        editReasonButton.setTitle("", for: .normal)
        setCurrentday(date: Date(), completion: { [self] result in
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
//              print("Handle Ok logic here")
            currentDay.specialSchedulesL1 = [block]()
            currentDay.specialSchedules = [block]()
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
                        inputKeyboardType: .default, actionHandler:
                            { [self] (input:String?) in
//            print("The new reason is \(input ?? "")")
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
            return currentDay.specialSchedulesL1.count
        }
        return currentDay.specialSchedules.count
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
                currentDay.specialSchedulesL1.remove(at: indexPath.row)
            }
            else {
                currentDay.specialSchedules.remove(at: indexPath.row)
            }
            tableView.reloadData()
            uploadData()
        }
    }
    func uploadData() {
        // get the date, access the data, upload the data *cool emoji*
        // set it locally as well
//        print("made it to upload zone")
        let formatter2 = DateFormatter()
        formatter2.dateStyle = .full
        let todaysDate = formatter2.string(from: realCurrentDate)

        LoginVC.specialSchedules["\(todaysDate)"] = currentDay
        var lunch1 = [[String:String]]()
        var lunch2 = [[String:String]]()
        for x in currentDay.specialSchedules {
            lunch2.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","startTime":"\(x.startTime)"])
        }
        for x in currentDay.specialSchedulesL1 {
            lunch1.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","startTime":"\(x.startTime)"])
        }
        let db = Firestore.firestore()
        let currDoc = db.collection("special-schedules").document("\(todaysDate)")
        currDoc.setData(["date":"\(todaysDate)", "reason":"\(currentDay.reason ?? "No Reason")", "blocks":lunch2,"blocks-l1":lunch1, "imageUrl":"\(currentDay.imageUrl ?? "")"])
    }
//    func uploadData() {
//        // FAKE UPLOAD DATA
////        print("made it to upload zone")
////        let formatter2 = DateFormatter()
////        formatter2.dateStyle = .full
////        let todaysDate = formatter2.string(from: realCurrentDate)
//        let weekNum = Calendar.current.component(.weekday, from: realCurrentDate)
////        print("\(weekNum)")
//        var day = ""
//        switch weekNum {
//        case 1:
//            day = "sunday"
//        case 2:
//            day = "monday"
//        case 3:
//            day = "tuesday"
//        case 4:
//            day = "wednesday"
//        case 5:
//            day = "thursday"
//        case 6:
//            day = "friday"
//        default:
//            day = "saturday"
//        }
////        LoginVC.specialSchedules["\(todaysDate)"] = currentDay
//        var lunch1 = [[String:String]]()
//        var lunch2 = [[String:String]]()
//        for x in currentDay.specialSchedules {
//            lunch2.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","startTime":"\(x.startTime)"])
//        }
//        for x in currentDay.specialSchedulesL1 {
//            lunch1.append(["block":"\(x.block)","endTime":"\(x.endTime)","name":"\(x.name)","startTime":"\(x.startTime)"])
//        }
//        let db = Firestore.firestore()
//        let currDoc = db.collection("default-schedules").document("\(day)")
//        currDoc.setData(["L2":lunch2, "L1":lunch1])
//    }
    @IBOutlet weak var addButton: UIButton!
    var currentDay = SpecialSchedule(specialSchedules: [block](), specialSchedulesL1: [block](), reason: "", date: "", imageUrl: nil, image: nil)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: EditableCell.identifier, for: indexPath) as? EditableCell else {
            fatalError()
        }
        var currentDayLunch = currentDay.specialSchedules
        if indexPath.section == 0 {
            currentDayLunch = currentDay.specialSchedulesL1
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
    func setCurrentday(date: Date, completion: @escaping (Swift.Result<SpecialSchedule, Error>) -> Void) {
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
            currentDay = SpecialSchedule(specialSchedules: defaultSchedules["monday"]?.L2 ?? [block](), specialSchedulesL1: defaultSchedules["monday"]?.L1 ?? [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 0
        case "Tuesday":
            currentDay = SpecialSchedule(specialSchedules: defaultSchedules["tuesday"]?.L2 ?? [block](), specialSchedulesL1: defaultSchedules["tuesday"]?.L1 ?? [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 1
        case "Wednesday":
            currentDay = SpecialSchedule(specialSchedules: defaultSchedules["wednesday"]?.L2 ?? [block](), specialSchedulesL1: defaultSchedules["wednesday"]?.L1 ?? [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 2
        case "Thursday":
            currentDay = SpecialSchedule(specialSchedules: defaultSchedules["thursday"]?.L2 ?? [block](), specialSchedulesL1: defaultSchedules["thursday"]?.L1 ?? [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 3
        case "Friday":
            currentDay = SpecialSchedule(specialSchedules: defaultSchedules["friday"]?.L2 ?? [block](), specialSchedulesL1: defaultSchedules["friday"]?.L1 ?? [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 4
        default:
            currentDay = SpecialSchedule(specialSchedules: [block](), specialSchedulesL1: [block](), reason: "", date: "", imageUrl: nil, image: nil)
            selectedDay = 10
        }
        if currentDay.specialSchedulesL1.isEmpty && currentDay.specialSchedules.isEmpty {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your Weekend")
        }
        else {
            ScheduleCalendar.restore()
        }
        if date.isBetweenTimeFrame(date1: "11 Jun 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Sep 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = SpecialSchedule(specialSchedules: [block](), specialSchedulesL1: [block]())
            completion(.success(currentDay))
            return
        }
        
        for x in LoginVC.specialSchedules {
            if x.key.lowercased() == stringDate.lowercased() {
                self.currentDay.specialSchedules = x.value.specialSchedules
                self.currentDay.specialSchedulesL1 = x.value.specialSchedulesL1
                self.currentDay.reason = x.value.reason ?? "No Reason"
                if self.currentDay.specialSchedules.isEmpty && self.currentDay.specialSchedulesL1.isEmpty {
                    if let z = x.value.imageUrl, z != "" {
                        // check for image
                        
                    }
                    else {
                        ScheduleCalendar.restore()
                        ScheduleCalendar.setEmptyMessage("No Class - \(self.currentDay.reason ?? "No Reason")")
                    }
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
    static var newBlock = customBlock(isFirstLunch: false, fullBlock: block(name: "", startTime: "", endTime: "", block: ""))
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


class BlockAndLunchVC: TextFieldVC {
    @IBOutlet weak var isFirstLunch: UISwitch!
    @IBOutlet weak var blockChoice: UIButton!
    @IBAction func pressed(_ sender: Any) {
        if blockPref == "" {
            return
        }
        SecretScheduleVC.newBlock = customBlock(isFirstLunch: isFirstLunch.isOn, fullBlock: block(name: "", startTime: "", endTime: "", block: blockPref))
        
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
class BlockNameVC: TextFieldVC {
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

class TimesVC: TextFieldVC {
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
        
        SecretScheduleVC.newBlock.fullBlock.startTime = startTime
        SecretScheduleVC.newBlock.fullBlock.endTime = endTime
        let blk = SecretScheduleVC.newBlock
        if blk.isFirstLunch {
            TimesVC.link.currentDay.specialSchedulesL1.append(blk.fullBlock)
        }
        else {
            TimesVC.link.currentDay.specialSchedules.append(blk.fullBlock)
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


class ImageVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet var imageButton: UIButton!
    @IBOutlet var tempImageView: UIImageView!
    @IBOutlet var finishButton: UIButton!
    var link: SecretScheduleVC!
    @IBAction func pressedFinish() {
        guard let image = tempImageView.image else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("You need to select an image!")
            return
        }
        let currDate = link.currentDate.replacingOccurrences(of: "/", with: "-")
        link.currentDay.image = image
        guard let imageData = image.pngData() else {
            return
        }
        finishButton.isEnabled = false
        let storageRef = Storage.storage().reference()
        storageRef.child("schedules/\(currDate).png").putData(imageData, metadata: nil, completion: { _, error in
            guard error == nil else {
                print("failed to upload \(String(describing: error))")
                ProgressHUD.showFailed("Failed to upload photo :(")
                return
            }
            DispatchQueue.main.async { [self] in
                let storage = FirebaseStorage.Storage.storage()
                let reference = storage.reference(withPath: "schedules/\(currDate).png")
                reference.downloadURL(completion: { [self] (url, error) in
                    if let error = error {
                        print(error)
                    }
                    else {
                        let urlstring = url!.absoluteString
                        guard let url = URL(string: urlstring) else {
                            return
                        }
                        DispatchQueue.main.async {[self] in
                            imageCache.setObject(image, forKey: NSString(string: urlstring))
                            dismiss(animated: true)
                            link.currentDay.imageUrl = "\(url)"
                            link.uploadData()
                        }
                    }
                })
            }
        })
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tempImageView.image = link.currentDay.image
    }
    @IBAction func choosePhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    @IBAction func takePhoto() {
        // fyi i could use the same method with a received button but im lazy
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    @IBAction func cancel () {
        dismiss(animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        tempImageView.image = image
    }
}
