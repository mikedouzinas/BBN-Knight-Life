//
//  SettingsVC.swift
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
import SkeletonView
import WebKit
import EventKit

/// The Settings sections, in the order they appear.
///
/// Named rather than numbered because the order CHANGED (HQ-656 added Manage Schedule as the
/// second section) and the old code compared `indexPath.section` against bare integers in
/// sixteen places. Renumbering those by hand is how a row ends up wired to the wrong action -
/// and a mis-wired row here runs "Clear My Classes" when somebody taps "Share".
enum SettingsSection: Int, CaseIterable {
    case personalInfo = 0
    /// Scan, Clear and Send Feedback, together, directly under Personal Info - the actions that
    /// SET UP a schedule, where a student looks for them, rather than buried under Other.
    case manageSchedule
    case blocks
    case preferences
    case lunch
    case other
}

/// The rows inside Manage Schedule, in order.
///
/// Named for the same reason `SettingsSection` is, one level down. Both the icon choice and the
/// tap handler were written as `indexPath.row == 0 ? scan : clear`, which is not "scan is first"
/// - it is "everything that is not row 0 clears the student's classes". Adding a third row to
/// that shape wires it to the destructive action.
enum ManageScheduleRow: Int, CaseIterable {
    case scan = 0
    case clear
    /// Beta feedback, and last on purpose: it is the least-used row, and putting it below the
    /// destructive one keeps Clear out of the position a thumb lands on by habit.
    case feedback

    var title: String {
        switch self {
        case .scan:     return "Scan Your Schedule"
        case .clear:    return "Clear My Classes"
        case .feedback: return "Report a Problem"
        }
    }

    var systemImage: String {
        switch self {
        case .scan:     return "camera.viewfinder"
        case .clear:    return "trash"
        case .feedback: return "exclamationmark.bubble"
        }
    }

    /// Only the destructive row is red, so it does not look like the others.
    var isDestructive: Bool { self == .clear }

    var badge: String? { self == .scan ? "Beta" : nil }
}

class SettingsVC: AuthVC, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITextFieldDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SettingsSection(rawValue: section) {
        case .personalInfo:    return profileCells.count
        case .manageSchedule:  return manageSchedule.count
        case .blocks:          return blocks.count
        case .lunch:           return lunchBlocks.count
        case .other:           return other.count
        default:               return 3 + preferenceBlocks.count
        }
    }
    private var other = [settingsBlock]()
    /// Scan Your Schedule, then Clear My Classes. Destructive last.
    private var manageSchedule = [settingsBlock]()
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let backview = UIView()
        backview.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor(named: "inverse")
        backview.addSubview(label)
        label.leftAnchor.constraint(equalTo: backview.leftAnchor, constant: 10).isActive = true
        label.centerYAnchor.constraint(equalTo: backview.centerYAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: backview.rightAnchor, constant: -5).isActive = true
        switch SettingsSection(rawValue: section) {
        case .personalInfo:   label.text = "Personal Info"
        case .manageSchedule: label.text = "Manage Schedule"
        case .blocks:         label.text = "Blocks"
        case .lunch:          label.text = "Lunch Configurations"
        case .other:          label.text = "Other"
        default:              label.text = "Preferences"
        }
        return backview
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == SettingsSection.personalInfo.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as? ProfileTableViewCell else {
                fatalError()
            }
            cell.configure(with: profileCells[indexPath.row])
            cell.selectionStyle = .none
            return cell
        }
        else if indexPath.section == SettingsSection.manageSchedule.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let row = ManageScheduleRow(rawValue: indexPath.row) ?? .scan
            let imageview = UIImageView(image: UIImage(systemName: row.systemImage)!)
            imageview.tintColor = row.isDestructive ? .systemRed : UIColor(named: "inverse")
            cell.accessoryView = imageview
            cell.configure(with: manageSchedule[indexPath.row])
            return cell
        }
        else if indexPath.section == SettingsSection.blocks.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
            imageview.tintColor = UIColor(named: "darkGray")
            cell.accessoryView = imageview
            cell.configure(with: blocks[indexPath.row])
            return cell
        }
        else if indexPath.section == SettingsSection.lunch.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
            imageview.tintColor = UIColor(named: "darkGray")
            cell.accessoryView = imageview
            cell.configure(with: lunchBlocks[indexPath.row])
            return cell
        }
        else if indexPath.section == SettingsSection.other.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            var imgName = "square.and.arrow.up"
            if indexPath.row == 1 { // google calendar add
                imgName = "calendar.circle"
            }
            else if indexPath.row == 2 { // apple calendar add
                imgName = "calendar.circle.fill"
            }
            else if indexPath.row == 3 { // HQ-656: scan your schedule
                imgName = "camera.viewfinder"
            }
            else if indexPath.row == 4 { // HQ-649: clear my classes
                imgName = "trash"
            }
            let imageview = UIImageView(image: UIImage(systemName: imgName)!)
            imageview.tintColor = UIColor(named: "inverse")
            cell.accessoryView = imageview
            cell.configure(with: other[indexPath.row])
            return cell
        }
        else {
            if indexPath.row == 0 {
                let cell = UITableViewCell()
                cell.selectionStyle = .none
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
                let label = UILabel()
                label.text = "Notifications"
                label.textColor = UIColor.systemGray
                label.font = .systemFont(ofSize: 14, weight: .regular)
                label.translatesAutoresizingMaskIntoConstraints = false
                let switcher = UISwitch()
                switcher.translatesAutoresizingMaskIntoConstraints = false
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    switcher.isOn = true
                }
                else {
                    switcher.isOn = false
                }
                switcher.addTarget(self, action: #selector(pressedSwitch(_:)), for: .touchUpInside)
                cell.contentView.addSubview(label)
                cell.contentView.addSubview(switcher)
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                label.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: 10).isActive = true
                switcher.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                switcher.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -20).isActive = true
                return cell
            }
            else if indexPath.row == 1 {
                let cell = UITableViewCell()
                cell.selectionStyle = .none
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
                let label = UILabel()
                label.text = "Profile Photo"
                label.textColor = UIColor.systemGray
                label.font = .systemFont(ofSize: 14, weight: .regular)
                label.translatesAutoresizingMaskIntoConstraints = false
                let switcher = UISwitch()
                switcher.translatesAutoresizingMaskIntoConstraints = false
                if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
                    switcher.isOn = true
                }
                else {
                    switcher.isOn = false
                }
                switcher.addTarget(self, action: #selector(pressedPhotoSwitch(_:)), for: .touchUpInside)
                cell.contentView.addSubview(label)
                cell.contentView.addSubview(switcher)
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                label.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: 10).isActive = true
                switcher.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                switcher.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -20).isActive = true
                return cell
            }
            else if indexPath.row == 2 {
                let cell = UITableViewCell()
                cell.selectionStyle = .none
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
                let label = UILabel()
                label.text = "Public Classes"
                label.textColor = UIColor.systemGray
                label.font = .systemFont(ofSize: 14, weight: .regular)
                label.translatesAutoresizingMaskIntoConstraints = false
                let switcher = UISwitch()
                switcher.translatesAutoresizingMaskIntoConstraints = false
                if ((LoginVC.blocks["publicClasses"] ?? "") as? String) == "true" {
                    switcher.isOn = true
                }
                else {
                    switcher.isOn = false
                }
                switcher.addTarget(self, action: #selector(pressedPublicClasses(_:)), for: .touchUpInside)
                cell.contentView.addSubview(label)
                cell.contentView.addSubview(switcher)
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                label.leftAnchor.constraint(equalTo: cell.leftAnchor, constant: 10).isActive = true
                switcher.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
                switcher.rightAnchor.constraint(equalTo: cell.rightAnchor, constant: -20).isActive = true
                return cell
            }
            else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                    fatalError()
                }
                let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
                imageview.tintColor = UIColor(named: "darkGray")
                cell.accessoryView = imageview
                cell.configure(with: preferenceBlocks[indexPath.row-3])
                return cell
            }
        }
    }
    @objc func pressedPhotoSwitch(_ switcher: UISwitch) {
        if switcher.isOn {
            LoginVC.updateField("googlePhoto", to: "true")
            setProfileImage(useGoogle: true, width: UInt(view.frame.width), completion: { [self]_ in
                setHeader()
//                SettingsVC.ProfileLink.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
        else {
            LoginVC.updateField("googlePhoto", to: "false")
            setProfileImage(useGoogle: false, width: UInt(view.frame.width), completion: { [self]_ in
                setHeader()
//                SettingsVC.ProfileLink.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Shared by the locker number and locker code fields.
        let maxLength = FieldLimits.lockerField
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)

        return newString.count <= maxLength
    }
    @objc func pressedPublicClasses(_ switcher: UISwitch) {
        LoginVC.updateField("publicClasses", to: switcher.isOn ? "true" : "false")
    }
    @objc func pressedSwitch(_ switcher: UISwitch) {
        LoginVC.updateField("notifs", to: switcher.isOn ? "true" : "false")
        setNotifications()
        ScheduleNotifications.syncSubscription()
    }
    // remove all cases of user when joining class too
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setBlocks()
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == SettingsSection.manageSchedule.rawValue {
            tableView.deselectRow(at: indexPath, animated: true)
            switch ManageScheduleRow(rawValue: indexPath.row) {
            case .scan:     navigationController?.pushViewController(ScheduleScanVC(), animated: true)
            case .clear:    confirmResetClasses()
            case .feedback: promptForFeedback(context: "settings")
            case .none:     break
            }
        }
        else if indexPath.section == SettingsSection.blocks.rawValue {
            tableView.deselectRow(at: indexPath, animated: true)
            ClassesOptionsPopupVC.currentBlock = "\(self.blocks[indexPath.row].blockName)"
            self.performSegue(withIdentifier: "options", sender: nil)
        }
        else if indexPath.section == SettingsSection.preferences.rawValue {
            if indexPath.row == 3 {
                let alertController = UIAlertController(title: "Grade", message: "Please enter your grade to better configure your schedule", preferredStyle: .actionSheet)
                
                // add the buttons/actions to the view controller
                let freshman = UIAlertAction(title: "Freshman", style: .default) { _ in
                    LoginVC.updateField("grade", to: "9")
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "9")
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let sophmore = UIAlertAction(title: "Sophmore", style: .default) { _ in
                    LoginVC.updateField("grade", to: "10")
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "10")
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let junior = UIAlertAction(title: "Junior", style: .default) { _ in
                    LoginVC.updateField("grade", to: "11")
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "11")
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let senior = UIAlertAction(title: "Senior", style: .default) { _ in
                    LoginVC.updateField("grade", to: "12")
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "12")
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let teacher = UIAlertAction(title: "Teacher", style: .default) { _ in
                    LoginVC.updateField("grade", to: "Teacher")
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "Teacher")
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    tableView.deselectRow(at: indexPath, animated: true)
                }
                alertController.addAction(freshman)
                alertController.addAction(sophmore)
                alertController.addAction(junior)
                alertController.addAction(senior)
                alertController.addAction(teacher)
                alertController.addAction(cancel)
                
                present(alertController, animated: true, completion: nil)
            }
            else if indexPath.row == 7 {
//                print("selected")
                tableView.deselectRow(at: indexPath, animated: true)
                let alertController = UIAlertController(title: "Appearance", message: "Please select your preferred appearance", preferredStyle: .actionSheet)
                
                // add the buttons/actions to the view controller
                let lightMode = UIAlertAction(title: "Light Mode", style: .default) { _ in
                    self.setAppearance(input: "Light Mode", indexPath: indexPath)
                }
                let darkMode = UIAlertAction(title: "Dark Mode", style: .default) { _ in
                    self.setAppearance(input: "Dark Mode", indexPath: indexPath)
                }
                let system = UIAlertAction(title: "Match System", style: .default) { _ in
                    self.setAppearance(input: "Match System", indexPath: indexPath)
                }
                let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                }
                alertController.addAction(lightMode)
                alertController.addAction(darkMode)
                alertController.addAction(system)
                alertController.addAction(cancel)
                
                present(alertController, animated: true, completion: nil)
            }
            else if indexPath.row > 3 {
                tableView.deselectRow(at: indexPath, animated: true)
                let alertController = UIAlertController(title: "\(preferenceBlocks[indexPath.row-3].blockName)", message: "Please enter your locker number", preferredStyle: .alert)
                var isLockerNum = true
                var isCode = false
                let prefName = "\(preferenceBlocks[indexPath.row-3].blockName.lowercased())"
                if prefName.contains("advisory") {
                    alertController.message = "Please enter your advisory room number"
                    isLockerNum = false
                }
                else if prefName.contains("code") {
                    alertController.message = "Please enter your locker code"
                    isCode = true
                }
                
                alertController.addTextField { (textField) in
                    // configure the properties of the text field
                    textField.placeholder = "e.g. 123"
                    textField.text = "\(self.preferenceBlocks[indexPath.row-3].className)"
                    textField.delegate = self
                }
                // add the buttons/actions to the view controller
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                    
                    // this code runs when the user hits the "save" button
                    
                    let inputName = alertController.textFields![0].text
                    if !isCode {
                        var name = ""
                        if isLockerNum {
                            name = "lockerNum"
                        }
                        else {
                            name = "room-advisory"
                        }
                        LoginVC.updateField(name, to: inputName ?? "")
                        self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: inputName!)
                    }
                    else {
                        let userDefaults = UserDefaults.standard
                        userDefaults.setValue(inputName, forKey: "lockerCode")
                        self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: inputName!)
                    }
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(saveAction)
                present(alertController, animated: true, completion: nil)
            }
        }
        else if indexPath.section == SettingsSection.lunch.rawValue {
            // Which block carries lunch on which weekday comes from the schedule itself
            // (`lunchWeekdaysInOrder`, derived from `regularSchedule`) rather than from a
            // hardcoded row-number switch. The rows and the schedule cannot disagree, and a
            // year in which BB&N moves lunch moves this list with it.
            let lunchWeekdays = lunchWeekdaysInOrder()
            let name = indexPath.row < lunchWeekdays.count
                ? lunchWeekdays[indexPath.row].block.lowercased()
                : "[Unknown]"
            let alertController = UIAlertController(title: "Lunch", message: "Please enter your lunch preference for \(name.count == 1 ? name.capitalized + " Block" : name.capitalized). You may need to restart the app to save your changes.", preferredStyle: .actionSheet)
            let lunch1 = UIAlertAction(title: "1st Lunch", style: .default) { _ in
                LoginVC.updateField("l-\(name)", to: "1st Lunch")
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "1st Lunch")
                //                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    self.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let lunch2 = UIAlertAction(title: "2nd Lunch", style: .default) { _ in
                LoginVC.updateField("l-\(name)", to: "2nd Lunch")
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "2nd Lunch")
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    self.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            }
            alertController.addAction(lunch1)
            alertController.addAction(lunch2)
            alertController.addAction(cancel)
            present(alertController, animated: true, completion: nil)
        }
        else if indexPath.section == SettingsSection.other.rawValue {
            tableView.deselectRow(at: indexPath, animated: true)
            switch indexPath.row {
            case 0: // share
                if shareSheetVC != nil { // shareSheetVC is initialized in the setBlocks method so it always has the user's most updated schedule
                    present(shareSheetVC!, animated: true)
                }
            case 1: // google calendar
                addItemToCalendar(pref: 0)
            default: // apple calendar
                addItemToCalendar(pref: 1)
            }
        }
    }
    func setAppearance(input: String?, indexPath: IndexPath) {
        self.setAppearance(input: input)
        self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "Appearance", className: "\(LoginVC.appearance)")
        tableView.reloadRows(at: [indexPath], with: .fade)
    }

    // HQ-649: confirm before wiping, and say what is about to be lost.
    func confirmResetClasses() {
        let alert = UIAlertController(
            title: "Clear My Classes?",
            message: "This removes all 7 of your blocks (A-G) and takes you off their class rosters. This can't be undone — you'll need to set your classes again from scratch.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { [weak self] _ in
            self?.performResetClasses()
        }))
        present(alert, animated: true)
    }

    /// Redraws the seven A-G rows from `LoginVC.blocks`.
    ///
    /// Named rather than written inline with a section number, because that number was `1` in two
    /// places and `1` stopped meaning Blocks the moment Manage Schedule was inserted above it. The
    /// wipe worked, the rows kept showing the cleared classes, and they only corrected when the
    /// student navigated into a block and back - which redraws the whole table for a different
    /// reason. It looked like a failed delete and was a repaint aimed at the wrong section.
    private func reloadBlockRows() {
        setBlocks()
        tableView.reloadSections(IndexSet(integer: SettingsSection.blocks.rawValue), with: .fade)
    }

    private func performResetClasses() {
        showLoader(text: "Clearing your classes...")
        resetClasses { [weak self] result in
            guard let self = self else { return }
            self.hideLoader(completion: {
                switch result {
                case .success:
                    ProgressHUD.colorAnimation = .green
                    ProgressHUD.succeed("Classes cleared")
                    self.reloadBlockRows()
                case .failure:
                    // Whatever got through before the failure is already durable (each block is
                    // committed before moving to the next), so this is safe to just retry.
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Didn't finish — some classes may still be set. Try again.")
                    self.reloadBlockRows()
                }
            })
        }
    }
    private var blocks = [settingsBlock]()
    private var preferenceBlocks = [settingsBlock]()
    private var lunchBlocks = [settingsBlock]()
//    static var ProfileLink: SideMenuViewController!
    private var profileCells = [ProfileCell]()
    private var tableView = UITableView()
    var shareSheetVC: UIActivityViewController?
    func setBlocks() {
        blocks = [
            settingsBlock(blockName: "A", className: LoginVC.blocks["A"] as? String ?? ""),
            settingsBlock(blockName: "B", className: LoginVC.blocks["B"] as? String ?? ""),
            settingsBlock(blockName: "C", className: LoginVC.blocks["C"] as? String ?? ""),
            settingsBlock(blockName: "D", className: LoginVC.blocks["D"] as? String ?? ""),
            settingsBlock(blockName: "E", className: LoginVC.blocks["E"] as? String ?? ""),
            settingsBlock(blockName: "F", className: LoginVC.blocks["F"] as? String ?? ""),
            settingsBlock(blockName: "G", className: LoginVC.blocks["G"] as? String ?? "")
        ]
        var a = (LoginVC.blocks["A"] as? String ?? "A Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var b = (LoginVC.blocks["B"] as? String ?? "B Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var c = (LoginVC.blocks["C"] as? String ?? "C Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var d = (LoginVC.blocks["D"] as? String ?? "D Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var e = (LoginVC.blocks["E"] as? String ?? "E Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var f = (LoginVC.blocks["F"] as? String ?? "F Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
        var g = (LoginVC.blocks["G"] as? String ?? "G Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
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
        shareSheetVC = UIActivityViewController(activityItems: ["\(LoginVC.fullName.trimmingCharacters(in: .whitespacesAndNewlines))'s Classes\nA: \(a.prefix(a.count-2))\nB: \(b.prefix(b.count-2))\nC: \(c.prefix(c.count-2))\nD: \(d.prefix(d.count-2))\nE: \(e.prefix(e.count-2))\nF: \(f.prefix(f.count-2))\nG: \(g.prefix(g.count-2))"], applicationActivities: nil)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.isNavigationBarHidden = false
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        setBlocks()
        let userDefaults = UserDefaults.standard
        let lockerCode = userDefaults.object(forKey: "lockerCode") as? String ?? ""
        preferenceBlocks = [
            settingsBlock(blockName: "Grade", className: "\(LoginVC.blocks["grade"] as? String ?? "")"),
            settingsBlock(blockName: "Locker Num", className: "\(LoginVC.blocks["lockerNum"] as? String ?? "")"),
            settingsBlock(blockName: "Locker Code", className: "\(lockerCode)"),
            settingsBlock(blockName: "Advisory Room", className: "\(LoginVC.blocks["room-advisory"] as? String ?? "")"),
            settingsBlock(blockName: "Appearance", className: "\(LoginVC.appearance)")
        ]
        
        // One row per weekday that has a lunch choice, built from the schedule rather than
        // typed out. The pairing used to be written here as display text ("D Block (Mondays)")
        // AND as a row-number switch in didSelectRowAt AND as `lunchBlock` on the L1/L2 events
        // in `regularSchedule` - three copies of one fact, and the label was the only one a
        // person would notice going wrong.
        lunchBlocks = lunchWeekdaysInOrder().map { pair in
            settingsBlock(
                blockName: "\(pair.block) Block (\(pair.weekday.capitalized)s)",
                className: "\(LoginVC.blocks[lunchPreferenceKey(forBlock: pair.block)] as? String ?? "")"
            )
        }
        other = [
            // Every row here DOES something rather than showing a value, so each is marked
            // isAction and its right-hand label stays empty. See settingsBlock in Structs.
            settingsBlock(blockName: "Share Your Classes", className: "", isAction: true),
            settingsBlock(blockName: "Add Schedule to Google Calendar", className: "", isAction: true),
            settingsBlock(blockName: "Add Schedule to Apple Calendar", className: "", isAction: true)
        ]
        // Kai's idea (PR 57), and the right one: the two actions that SET UP a schedule belong
        // together near the top, not at the bottom of a list that starts with "Share".
        // Destructive last, so a mis-tap on Scan is not a wipe.
        // Built from the enum rather than written out, so the rows, their icons, and the tap
        // handler cannot get out of step with each other. "Beta" is a badge on the scan row: it
        // reads one photo per student in the first week of the year, on sheets nobody here has
        // seen, and a student should know that BEFORE they trust it over typing seven classes in
        // by hand rather than after it gets one wrong.
        manageSchedule = ManageScheduleRow.allCases.map {
            settingsBlock(blockName: $0.title, className: "", isAction: true, badge: $0.badge)
        }
        tableView = UITableView(frame: .zero, style: .grouped)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.backgroundColor = UIColor(named: "background")
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 20))
        button.setTitle(" About", for: .normal)
        button.setTitleColor(UIColor(named: "inverse"), for: .normal)
        button.setImage(UIImage(systemName: "info.circle"), for: .normal)
        button.tintColor = UIColor(named: "inverse")
        button.addTarget(self, action: #selector(openCredits), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        let smallview = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40))
        smallview.addSubview(button)
        button.centerXAnchor.constraint(equalTo: smallview.centerXAnchor).isActive = true
        button.topAnchor.constraint(equalTo: smallview.topAnchor).isActive = true
        tableView.tableFooterView = smallview
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.register(SettingsBlockTableViewCell.self, forCellReuseIdentifier: SettingsBlockTableViewCell.identifier)
        self.profileCells = [ProfileCell(title: "Email Address", data: "\(LoginVC.email)")]
        var i = 0
        for x in self.profileCells {
            if x.data == "" {
                self.profileCells.remove(at: i)
                i-=1
            }
            i+=1
        }
        self.tableView.reloadData()
        setHeader()
    }
    @IBAction func closeClass(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    func setHeader() {
        let header = StretchyTableHeaderView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.width-50))
        header.imageview.image = LoginVC.profilePhoto.image
        header.nameLabel.text = LoginVC.fullName.capitalized
        tableView.tableHeaderView = header
    }
    @objc func openCredits() {
        self.performSegue(withIdentifier: "Credits", sender: nil)
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let header = tableView.tableHeaderView as? StretchyTableHeaderView else {
            return
        }
        header.scrollViewDidScroll(scrollView: tableView)
    }
    
    // function loops through and adds repeating *normal* schedule to google or apple calendar, respectively
    func addItemToCalendar(pref: Int) {
        let alert = UIAlertController(title: "Coming Soon™", message: "sorry :(", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        
//        let alertController = UIAlertController(title: "Add Events",
//                                                message: "Are you sure you want to add all events to your calendar?",
//                                                preferredStyle: .alert)
//        
//        let confirmAction = UIAlertAction(title: "Yes", style: .default) { [self] (_) in
//            if pref == 0 { // google calendar
//                updateGoogleCalendar()
//            }
//            else { // apple calendar
//                updateAppleCalendar()
//            }
//        }
//        alertController.addAction(confirmAction)
//            
//        let cancelAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
//        alertController.addAction(cancelAction)
//        
//        present(alertController, animated: true, completion: nil)
        
    }
    
    // updates google or apple calendar for special schedules. It should check for all special schedules and add (or remove) specific places where it could be faulty
    func updateGoogleCalendar() {
        
        
    }
    
    func updateAppleCalendar() {
        requestCalendarAccess { [self] result in
            if result {
                deleteExistingKnightLifeEvents {
                    self.addWeekLongScheduleToCalendar()
                }
            }
        }
    }
    let eventStore = EKEventStore()
    var regularBlocks = [[block]]()
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        let authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                
        if authorizationStatus == .authorized {
            completion(true)
        } else if authorizationStatus == .notDetermined {
            eventStore.requestAccess(to: .event) { (granted, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error requesting calendar access: \(error.localizedDescription)")
                        completion(false)
                    }
                    completion(granted)
                }
            }
        } else {
            completion(false)
        }
    }
    
    private func showCalendarAccessDeniedAlert() {
        let alert = UIAlertController(title: "Calendar Access Denied", message: "Please allow access to your calendar in the Settings app.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    func addWeekLongScheduleToCalendar() {
        let selectedCalendar = EKSourceType.local
        
        guard let calendar = eventStore.calendars(for: .event).first(where: { $0.source.sourceType == selectedCalendar }) else {
            print("no calendar")
            return
        }
        
        // default schedule for the week w/ correct lunches
//        regularBlocks = [getLunchDays(weekDay: "monday").blocks,getLunchDays(weekDay: "tuesday").blocks,getLunchDays(weekDay: "wednesday").blocks,getLunchDays(weekDay: "thursday").blocks,getLunchDays(weekDay: "friday").blocks]
        regularBlocks = [getRegularSchedule(weekday: "monday").blocks,getRegularSchedule(weekday: "tuesday").blocks,getRegularSchedule(weekday: "wednesday").blocks,getRegularSchedule(weekday: "thursday").blocks,getRegularSchedule(weekday: "friday").blocks]
        var weekday = 2
        for day in regularBlocks {
            for event in day {
                let date = nextWeekday(weekday: weekday)
                let title = getTitleForBlock(x: event, weekNum: weekday, notif: false)
                addEventToCalendar(calendar: calendar, title: title, startDate: getBlockOnDate(date: date, time: event.startTime), endDate: getBlockOnDate(date: date, time: event.endTime))
            }
            weekday+=1
        }
        ProgressHUD.succeed("Added Schedule to Calendar!")
    }
    
    private func addEventToCalendar(calendar: EKCalendar, title: String, startDate: Date, endDate: Date) {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        
        // Add a unique identifier as a note
        event.notes = "KnightLifeScheduleIdentifier"
        
        // Create a notification 5 minutes before the event
        let notification = EKAlarm(relativeOffset: -5 * 60)
        event.addAlarm(notification)
        
        // recurs every week until end of school
        event.addRecurrenceRule(.init(recurrenceWith: .weekly, interval: 1, end: createRecurrenceEnd()))
        
//        // Adds a recurrence rule to avoid special schedule dates. I should maybe loop through here to check for each individual one but i'll figure this out
//        let calendar = Calendar.current
//        var exceptionDates = [Date]()
//        
//        for x in LoginVC.specialSchedules {
//            // if something is a special schedule date, we don't add it to calendar
//            if let specialDate = x.key.dateFromMultipleFormats() {
//                exceptionDates.append(specialDate)
//            }
//        }
//        event.exceptionDates = exceptionDates
//        
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Error saving event: \(error.localizedDescription)")
        }
    }
    
    func deleteExistingKnightLifeEvents(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            let allCalendars = self.eventStore.calendars(for: .event)
            let predicate = self.eventStore.predicateForEvents(withStart: Date(),
                                                               end: Date.distantFuture,
                                                               calendars: allCalendars)
            
            let events = self.eventStore.events(matching: predicate)
            for event in events {
                // Check if the event has the unique identifier in its notes
                if event.notes == "KnightLifeScheduleIdentifier" {
                    do {
                        try self.eventStore.remove(event, span: .thisEvent, commit: false)
                    } catch {
                        print("Error deleting event: \(error.localizedDescription)")
                    }
                }
            }
            
            // Commit changes and call completion handler
            do {
                try self.eventStore.commit()
                completion()
            } catch {
                print("Error committing event store changes: \(error.localizedDescription)")
                completion()
            }
        }
    }
    
    private func createRecurrenceEnd() -> EKRecurrenceEnd? {
        // Set the recurrence end date to June 2. Yes, this is hard coded, but it should edited each year to be the final day of classes.
        var components = DateComponents()
        components.year = Calendar.current.component(.year, from: Date())
        components.month = 6
        components.day = 2
        
        guard let endDate = Calendar.current.date(from: components) else {
            print("Failed to create recurrence end date.")
            return nil
        }
        
        return EKRecurrenceEnd(end: endDate)
    }
}
