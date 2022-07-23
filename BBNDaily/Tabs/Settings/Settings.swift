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

class SettingsVC: AuthVC, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITextFieldDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return profileCells.count
        }
        else if section == 1 {
            return blocks.count
        }
        else if section == 3 {
            return lunchBlocks.count
        }
        else if section == 4 {
            return other.count
        }
        return (3 + preferenceBlocks.count)
    }
    private var other = [settingsBlock]()
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
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
        if section == 0 {
            label.text = "Personal Info."
        }
        else if section == 1 {
            label.text = "Blocks"
        }
        else if section == 3 {
            label.text = "Lunch Configurations"
        }
        else if section == 4 {
            label.text = "Other"
        }
        else {
            label.text = "Preferences"
        }
        return backview
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as? ProfileTableViewCell else {
                fatalError()
            }
            cell.configure(with: profileCells[indexPath.row])
            cell.selectionStyle = .none
            return cell
        }
        else if indexPath.section == 1 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
            imageview.tintColor = UIColor(named: "darkGray")
            cell.accessoryView = imageview
            cell.configure(with: blocks[indexPath.row])
            return cell
        }
        else if indexPath.section == 3 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
            imageview.tintColor = UIColor(named: "darkGray")
            cell.accessoryView = imageview
            cell.configure(with: lunchBlocks[indexPath.row])
            return cell
        }
        else if indexPath.section == 4 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                fatalError()
            }
            let imageview = UIImageView(image: UIImage(systemName: "square.and.arrow.up")!)
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
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["googlePhoto"] = "true"
            currDoc.setData(LoginVC.blocks)
            LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width), completion: { [self]_ in
                setHeader()
                SettingsVC.ProfileLink.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["googlePhoto"] = "false"
            currDoc.setData(LoginVC.blocks)
            LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width), completion: { [self]_ in
                setHeader()
                SettingsVC.ProfileLink.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 10
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)

        return newString.count <= maxLength
    }
    @objc func pressedPublicClasses(_ switcher: UISwitch) {
        if switcher.isOn {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["publicClasses"] = "true"
            currDoc.setData(LoginVC.blocks)
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["publicClasses"] = "false"
            currDoc.setData(LoginVC.blocks)
        }
    }
    @objc func pressedSwitch(_ switcher: UISwitch) {
        if switcher.isOn {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["notifs"] = "true"
            currDoc.setData(LoginVC.blocks)
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["notifs"] = "false"
            currDoc.setData(LoginVC.blocks)
        }
        setNotifications()
    }
    // remove all cases of user when joining class too
    override func viewWillAppear(_ animated: Bool) {
        setBlocks()
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            tableView.deselectRow(at: indexPath, animated: true)
            ClassesOptionsPopupVC.currentBlock = "\(self.blocks[indexPath.row].blockName)"
            self.performSegue(withIdentifier: "options", sender: nil)
        }
        else if indexPath.section == 2 {
            if indexPath.row == 3 {
                let alertController = UIAlertController(title: "Grade", message: "Please enter your grade to better configure your schedule", preferredStyle: .actionSheet)
                
                // add the buttons/actions to the view controller
                let freshman = UIAlertAction(title: "Freshman", style: .default) { _ in
                    LoginVC.blocks["grade"] = "9"
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "9")
                    //                self.pr
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let sophmore = UIAlertAction(title: "Sophmore", style: .default) { _ in
                    LoginVC.blocks["grade"] = "10"
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "10")
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let junior = UIAlertAction(title: "Junior", style: .default) { _ in
                    LoginVC.blocks["grade"] = "11"
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "11")
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let senior = UIAlertAction(title: "Senior", style: .default) { _ in
                    LoginVC.blocks["grade"] = "12"
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "12")
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                let teacher = UIAlertAction(title: "Teacher", style: .default) { _ in
                    LoginVC.blocks["grade"] = "Teacher"
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: "Teacher")
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
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
            else if indexPath.row == 6 {
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
                var isLocker = true
                if preferenceBlocks[indexPath.row-3].blockName.lowercased().contains("advisory") {
                    alertController.message = "Please enter your advisory room number"
                    isLocker = false
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
                    var name = ""
                    if isLocker {
                        name = "lockerNum"
                    }
                    else {
                        name = "room-advisory"
                    }
                    LoginVC.blocks["\(name)"] = inputName
                    self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-3].blockName)", className: inputName!)
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                    currDoc.setData(LoginVC.blocks)
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(saveAction)
                present(alertController, animated: true, completion: nil)
            }
        }
        else if indexPath.section == 3 {
            var name = ""
            switch indexPath.row {
            case 0:
                name = "monday"
            case 1:
                name = "tuesday"
            case 2:
                name = "wednesday"
            case 3:
                name = "thursday"
            default:
                name = "friday"
            }
            let alertController = UIAlertController(title: "Lunch", message: "Please enter your lunch preference for \(name.capitalized). You may need to restart the app to save your changes.", preferredStyle: .actionSheet)
            let lunch1 = UIAlertAction(title: "1st Lunch", style: .default) { _ in
                LoginVC.blocks["l-\(name)"] = "1st Lunch"
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "1st Lunch")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                //                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    self.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let lunch2 = UIAlertAction(title: "2nd Lunch", style: .default) { _ in
                LoginVC.blocks["l-\(name)"] = "2nd Lunch"
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "2nd Lunch")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
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
        else if indexPath.section == 4 {
            tableView.deselectRow(at: indexPath, animated: true)
            if shareSheetVC != nil {
                present(shareSheetVC!, animated: true)
            }
        }
    }
    func setAppearance(input: String?, indexPath: IndexPath) {
        self.setAppearance(input: input)
        self.preferenceBlocks[indexPath.row-3] = settingsBlock(blockName: "Appearance", className: "\(LoginVC.appearance)")
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    private var blocks = [settingsBlock]()
    private var preferenceBlocks = [settingsBlock]()
    private var lunchBlocks = [settingsBlock]()
    static var ProfileLink: SideMenuViewController!
    private var profileCells = [ProfileCell]()
    private var tableView = UITableView()
    @objc func signOut() {
        let refreshAlert = UIAlertController(title: "Sign Out?", message: "Are you sure you want to sign out?", preferredStyle: UIAlertController.Style.alert)
        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            self.signOutToken()
        }))
        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))
        present(refreshAlert, animated: true, completion: nil)
    }
    var SignOutButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = UIColor(named: "gold")
        b.setTitle("Sign Out", for: .normal)
        b.setTitleColor(UIColor.white, for: .normal)
        b.layer.masksToBounds = true
        b.layer.cornerRadius = 8
        b.dropShadow()
        return b
    }()
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
    public let closeButton: UIButton = {
        let button = UIButton()
        button.setTitle("", for: .normal)
        button.setImage(UIImage(named: "x-mark"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.dropShadow()
        button.backgroundColor = .clear
        return button
    } ()
    @objc func close(_ sender: Any) {
//        print("made it?")
        dismiss(animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        view.addSubview(SignOutButton)
        SignOutButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        SignOutButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        SignOutButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15).isActive = true
        SignOutButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        SignOutButton.addTarget(self, action: #selector(signOut), for: .touchUpInside)
        setBlocks()
        
        preferenceBlocks = [
            settingsBlock(blockName: "Grade", className: "\(LoginVC.blocks["grade"] as? String ?? "")"),
            settingsBlock(blockName: "Locker #", className: "\(LoginVC.blocks["lockerNum"] as? String ?? "")"),
            settingsBlock(blockName: "Advisory Room", className: "\(LoginVC.blocks["room-advisory"] as? String ?? "")"),
            settingsBlock(blockName: "Appearance", className: "\(LoginVC.appearance)")
        ]
        
        lunchBlocks = [
            settingsBlock(blockName: "Monday Lunch", className: "\(LoginVC.blocks["l-monday"] as? String ?? "")"),
            settingsBlock(blockName: "Tuesday Lunch", className: "\(LoginVC.blocks["l-tuesday"] as? String ?? "")"),
            settingsBlock(blockName: "Wednesday Lunch", className: "\(LoginVC.blocks["l-wednesday"] as? String ?? "")"),
            settingsBlock(blockName: "Thursday Lunch", className: "\(LoginVC.blocks["l-thursday"] as? String ?? "")"),
            settingsBlock(blockName: "Friday Lunch", className: "\(LoginVC.blocks["l-friday"] as? String ?? "")")
        ]
        other = [
            settingsBlock(blockName: "Share Your Classes", className: "")
        ]
        tableView = UITableView(frame: .zero, style: .grouped)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: SignOutButton.topAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.backgroundColor = UIColor(named: "background")
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        let secretButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        secretButton.setTitle("", for: .normal)
        secretButton.setImage(UIImage(systemName: "star.circle"), for: .normal)
        secretButton.tintColor = UIColor(named: "inverse")
        secretButton.addTarget(self, action: #selector(openSecretSchedule), for: .touchUpInside)
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 20))
        button.setTitle("Credits & Feedback", for: .normal)
        button.setTitleColor(UIColor(named: "gold"), for: .normal)
        button.addTarget(self, action: #selector(openCredits), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        secretButton.translatesAutoresizingMaskIntoConstraints = false
        let smallview = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 80))
        smallview.addSubview(button)
        smallview.addSubview(secretButton)
        secretButton.centerXAnchor.constraint(equalTo: smallview.centerXAnchor).isActive = true
        button.centerXAnchor.constraint(equalTo: smallview.centerXAnchor).isActive = true
        button.topAnchor.constraint(equalTo: smallview.topAnchor).isActive = true
        secretButton.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 5).isActive = true
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
//        closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
//        view.addSubview(closeButton)
//        closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10).isActive = true
//        closeButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 10).isActive = true
//        closeButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
//        closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor).isActive = true
        setHeader()
    }
    @IBAction func closeClass(_ sender: Any) {
//        print("made it?")
        dismiss(animated: true, completion: nil)
    }
    @objc func openSecretSchedule() {
        if LoginVC.email.contains("mveson") {
            self.performSegue(withIdentifier: "secretSchedule", sender: nil)
        }
        else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("Oh no! Looks like you just got rejected.")
        }
    }
    func setHeader() {
        let header = StretchyTableHeaderView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.width))
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
}

