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
import WebKit

class SettingsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
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
        return (2 + preferenceBlocks.count)
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
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
//                    LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width), completion: {_ in
                        
//                    })
                }
                else {
                    switcher.isOn = false
//                    LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width), completion: {_ in

//                    })
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
            else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsBlockTableViewCell.identifier, for: indexPath) as? SettingsBlockTableViewCell else {
                    fatalError()
                }
                let imageview = UIImageView(image: UIImage(systemName: "chevron.right")!)
                imageview.tintColor = UIColor(named: "darkGray")
                cell.accessoryView = imageview
                cell.configure(with: preferenceBlocks[indexPath.row-2])
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
            })
           
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["googlePhoto"] = "false"
            currDoc.setData(LoginVC.blocks)
            LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width), completion: { [self]_ in
                setHeader()
            })
        }
    }
    @objc func pressedSwitch(_ switcher: UISwitch) {
        if switcher.isOn {
            LoginVC.setNotifications()
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["notifs"] = "true"
            currDoc.setData(LoginVC.blocks)
            //            UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { results in
            //                for x in results {
            //                    print("title: \(x.content.title) ")
            //                }
            //            })
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["notifs"] = "false"
            currDoc.setData(LoginVC.blocks)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        setBlocks()
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            tableView.deselectRow(at: indexPath, animated: true)
            ClassesOptionsPopupVC.currentBlock = "\(self.blocks[indexPath.row].blockName)"
            self.performSegue(withIdentifier: "options", sender: nil)
//            let alertController = UIAlertController(title: "\(blocks[indexPath.row].blockName) Block", message: "Enter your class for \(blocks[indexPath.row].blockName) block followed by the room number", preferredStyle: .alert)
//
//            alertController.addTextField { (textField) in
//                // configure the properties of the text field
//                textField.placeholder = "e.g. Math A-370"
//                textField.text = "\(self.blocks[indexPath.row].className)"
//            }
//
//
//            // add the buttons/actions to the view controller
//            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
//
//                // this code runs when the user hits the "save" button
//
//                let inputName = alertController.textFields![0].text
//                LoginVC.blocks["\(self.blocks[indexPath.row].blockName)"] = inputName
//                self.blocks[indexPath.row] = settingsBlock(blockName: "\(self.blocks[indexPath.row].blockName)", className: inputName!)
//                let db = Firestore.firestore()
//                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
//                currDoc.setData(LoginVC.blocks)
//                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
//                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
//                    LoginVC.setNotifications()
//                }
//                tableView.reloadRows(at: [indexPath], with: .fade)
//            }
//
//            alertController.addAction(cancelAction)
//            alertController.addAction(saveAction)
//
//            present(alertController, animated: true, completion: nil)
        }
        else if indexPath.section == 2 && indexPath.row == 2 {
            let alertController = UIAlertController(title: "Grade", message: "Please enter your grade to better configure your schedule", preferredStyle: .actionSheet)
            
            // add the buttons/actions to the view controller
            let freshman = UIAlertAction(title: "Freshman", style: .default) { _ in
                LoginVC.blocks["grade"] = "9"
                self.preferenceBlocks[indexPath.row-2] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-2].blockName)", className: "9")
                //                self.pr
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let sophmore = UIAlertAction(title: "Sophmore", style: .default) { _ in
                LoginVC.blocks["grade"] = "10"
                self.preferenceBlocks[indexPath.row-2] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-2].blockName)", className: "10")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let junior = UIAlertAction(title: "Junior", style: .default) { _ in
                LoginVC.blocks["grade"] = "11"
                self.preferenceBlocks[indexPath.row-2] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-2].blockName)", className: "11")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                CalendarVC.isLunch1 = false
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let senior = UIAlertAction(title: "Senior", style: .default) { _ in
                LoginVC.blocks["grade"] = "12"
                self.preferenceBlocks[indexPath.row-2] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-2].blockName)", className: "12")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                CalendarVC.isLunch1 = false
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                tableView.deselectRow(at: indexPath, animated: true)
            }
            alertController.addAction(freshman)
            alertController.addAction(sophmore)
            alertController.addAction(junior)
            alertController.addAction(senior)
            alertController.addAction(cancel)
            
            present(alertController, animated: true, completion: nil)
        }
        else if indexPath.section == 2 && indexPath.row > 2 {
            tableView.deselectRow(at: indexPath, animated: true)
            let alertController = UIAlertController(title: "\(preferenceBlocks[indexPath.row-2].blockName)", message: "Please enter your locker number", preferredStyle: .alert)
            var isLocker = true
            if preferenceBlocks[indexPath.row-2].blockName.lowercased().contains("advisory") {
                alertController.message = "Please enter your advisory room number"
                isLocker = false
            }
            alertController.addTextField { (textField) in
                // configure the properties of the text field
                textField.placeholder = "e.g. 123"
                textField.text = "\(self.preferenceBlocks[indexPath.row-2].className)"
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
                self.preferenceBlocks[indexPath.row-2] = settingsBlock(blockName: "\(self.preferenceBlocks[indexPath.row-2].blockName)", className: inputName!)
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(saveAction)
            
            present(alertController, animated: true, completion: nil)
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
            let alertController = UIAlertController(title: "Lunch", message: "Please enter your lunch preference for \(name.capitalized)", preferredStyle: .actionSheet)
            let lunch1 = UIAlertAction(title: "1st Lunch", style: .default) { _ in
                LoginVC.blocks["l-\(name)"] = "1st Lunch"
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "1st Lunch")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
//                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            let lunch2 = UIAlertAction(title: "2nd Lunch", style: .default) { _ in
                LoginVC.blocks["l-\(name)"] = "2nd Lunch"
                self.lunchBlocks[indexPath.row] = settingsBlock(blockName: "\(self.lunchBlocks[indexPath.row].blockName)", className: "2nd Lunch")
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
//                CalendarVC.isLunch1 = true
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
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
    }
    func callReset() {
        ProgressHUD.colorAnimation = .green
        ProgressHUD.showSucceed("Successfully signed out")
        self.performSegue(withIdentifier: "Reset", sender: nil)
    }
    private var blocks = [settingsBlock]()
    private var preferenceBlocks = [settingsBlock]()
    private var lunchBlocks = [settingsBlock]()
    
    private var profileCells = [ProfileCell]()
    private var tableView = UITableView()
    @objc func signOut() {
        let refreshAlert = UIAlertController(title: "Sign Out?", message: "Are you sure you want to sign out?", preferredStyle: UIAlertController.Style.alert)
        
        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
            do {
                try FirebaseAuth.Auth.auth().signOut()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                self.callReset()
            }
            catch {
                ProgressHUD.showFailed("Failed to Sign Out")
            }
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
            settingsBlock(blockName: "Advisory Room", className: "\(LoginVC.blocks["room-advisory"] as? String ?? "")")
        ]
        
        lunchBlocks = [
            settingsBlock(blockName: "Monday Lunch", className: "\(LoginVC.blocks["l-monday"] as? String ?? "")"),
            settingsBlock(blockName: "Tuesday Lunch", className: "\(LoginVC.blocks["l-tuesday"] as? String ?? "")"),
            settingsBlock(blockName: "Wednesday Lunch", className: "\(LoginVC.blocks["l-wednesday"] as? String ?? "")"),
            settingsBlock(blockName: "Thursday Lunch", className: "\(LoginVC.blocks["l-thursday"] as? String ?? "")"),
            settingsBlock(blockName: "Friday Lunch", className: "\(LoginVC.blocks["l-friday"] as? String ?? "")")
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
        let button = UIButton(frame: CGRect(x: 0, y: 30, width: 30, height: 50))
        button.setTitle("Credits & Feedback", for: .normal)
        button.setTitleColor(UIColor(named: "gold"), for: .normal)
        button.addTarget(self, action: #selector(openCredits), for: .touchUpInside)
        tableView.tableFooterView = button
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
    func setHeader() {
        
        let header = StretchyTableHeaderView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.width))
        //        header.imageview.image = UIImage(named: "DefaultUserPhoto")
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


struct settingsBlock {
    let blockName: String
    let className: String
}

class SettingsBlockTableViewCell: UITableViewCell {
    static let identifier = "SettingsBlockTableViewCell"
    private let TitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let DataLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.systemBlue
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier )
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DataLabel)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: DataLabel.leftAnchor, constant: -5).isActive = true
        DataLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        DataLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }
    func configure(with viewModel: settingsBlock) {
        backgroundColor = UIColor(named: "background")
        if viewModel.blockName.count > 1 {
            TitleLabel.text = "\(viewModel.blockName)"
        }
        else {
            TitleLabel.text = "\(viewModel.blockName) Block"
        }
        if viewModel.className != "" {
            DataLabel.text = viewModel.className
        }
        else {
            if viewModel.blockName.count > 1 {
                DataLabel.text = "Not set"
            }
            else if viewModel.blockName.lowercased().contains("lunch") {
                DataLabel.text = "2nd Lunch"
            }
            else {
                DataLabel.text = "[Class] [Room #]"
            }
        }
    }
}

class ProfileTableViewCell: UITableViewCell {
    static let identifier = "ProfileTableViewCell"
    private let TitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let DataLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.systemBlue
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier )
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DataLabel)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        
        DataLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        DataLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
    }
    func configure(with viewModel: ProfileCell) {
        contentView.backgroundColor = UIColor(named: "background")
        TitleLabel.text = viewModel.title
        DataLabel.text = viewModel.data
    }
}

final class StretchyTableHeaderView: UIView {
    public let imageview: UIImageView = {
        let image = UIImageView()
        
        image.clipsToBounds = true
        return image
    } ()
    public let nameLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        label.dropShadow(scale: true, radius: 50)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 8
        label.padding(2, 2, 8, 8)
        return label
    } ()
    private var imageViewHeight = NSLayoutConstraint()
    private var imageViewBottom = NSLayoutConstraint()
    private var containerView = UIView()
    private var containerViewHeight = NSLayoutConstraint()
    override init(frame: CGRect) {
        super.init(frame: frame)
        createViews()
        setViewConstraints()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    private func createViews() {
        addSubview(containerView)
        containerView.addSubview(imageview)
        addSubview(nameLabel)
    }
    func setViewConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: containerView.widthAnchor),
            centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.widthAnchor.constraint(equalTo: imageview.widthAnchor).isActive = true
        containerViewHeight = containerView.heightAnchor.constraint(equalTo: self.heightAnchor)
        containerViewHeight.isActive = true
        
        imageview.translatesAutoresizingMaskIntoConstraints = false
        imageViewBottom = imageview.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        imageViewBottom.isActive = true
        imageViewHeight = imageview.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        imageViewHeight.isActive = true
        
        nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20).isActive = true
        nameLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 20).isActive = true
    }
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        containerViewHeight.constant = scrollView.contentInset.top
        let offsetY = -(scrollView.contentOffset.y + scrollView.contentInset.top)
        containerView.clipsToBounds = offsetY <= 0
        imageViewBottom.constant = offsetY >= 0 ? 0 : -offsetY / 2
        imageViewHeight.constant = max(offsetY + scrollView.contentInset.top, scrollView.contentInset.top)
    }
}

struct ProfileCell {
    var title: String
    var data: String
}

class CreditsVC: UIViewController {
    @IBAction func close(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func openSheet(_ sender: Any) {
        if let url = URL(string: "https://docs.google.com/spreadsheets/d/1A1CLxugRIGmxIV595mbiR6noLdw4ShuxAKe-tjxATCc/edit?usp=sharing") {
            UIApplication.shared.open(url)
        }
    }
    @IBAction func openLibraries(_ sender: Any) {
        self.performSegue(withIdentifier: "OpenSource", sender: nil)
    }
}

class AboutUsVC: CustomLoader, WKNavigationDelegate, UITableViewDataSource, UITableViewDelegate{
    @IBOutlet var sideMenuBtn: UIBarButtonItem!
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = UIColor(named: "background")
        table.register(AboutTableViewCell.self,
                       forCellReuseIdentifier: AboutTableViewCell.identifier)
        return table
    }()
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Open Source Libraries"
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Libraries Used"
        view.backgroundColor = UIColor(named: "background")
        tableView.tableFooterView = UIView(frame: .zero)
        setData()
        tableView.backgroundColor = UIColor (named: "background")
    }
    func setData() {
        view.addSubview(tableView)
        var libraries2 = [Library]()
        libraries2.append(Library(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk/blob/master/LICENSE"))
        libraries2.append(Library(name: "Google Sign In", url: "https://github.com/google/GoogleSignIn-iOS/blob/main/LICENSE"))
        libraries2.append(Library(name: "FS Calendar", url: "https://github.com/WenchaoD/FSCalendar/blob/master/LICENSE"))
        libraries2.append(Library(name: "ICONS8", url: "https://icons8.com/vue-static/landings/pricing/icons8-license.pdf"))
        libraries2.append(Library(name: "Progress HUD", url: "https://github.com/relatedcode/ProgressHUD/blob/master/LICENSE"))
        libraries2.append(Library(name: "Bubble Tab Bar", url: "https://github.com/Cuberto/bubble-icon-tabbar/blob/master/LICENSE"))
        libraries2.append(Library(name: "Initials ImageView", url: "https://github.com/bachonk/InitialsImageView/blob/master/LICENSE"))
        tableViewData.append(Libraries(libraries: libraries2))
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.delegate = self
    }
    var tableViewData = [Libraries]()
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewData[section].libraries.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let library = tableViewData[indexPath.section].libraries[indexPath.row]
        let vc = SFSafariViewController(url: URL(string: library.url)!)
        present(vc, animated: true)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.identifier,
                                                 for: indexPath) as! AboutTableViewCell
        cell.selectionStyle = .none
        cell.configure(with: tableViewData[indexPath.section].libraries[indexPath.row])
        return cell
    }
}


class AboutTableViewCell: UITableViewCell {
    static let identifier = "AboutTableViewCell"
    let leftLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
        //        contentView.backgroundColor =  UIColor(named: "inverseBackgroundCol")?.withAlphaComponent(0.1)
        leftLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        leftLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(leftLabel)
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    public func configure(with viewModel: Library) {
        accessoryType = .disclosureIndicator
        leftLabel.text = "\(viewModel.name)"
    }
}

struct Libraries {
    let libraries: [Library]
}

struct Library {
    let name: String
    let url: String
}

class PaddingLabel: UILabel {
    
    var insets = UIEdgeInsets.zero
    
    func padding(_ top: CGFloat, _ bottom: CGFloat, _ left: CGFloat, _ right: CGFloat) {
        self.frame = CGRect(x: 0, y: 0, width: self.frame.width + left + right, height: self.frame.height + top + bottom)
        insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += insets.top + insets.bottom
            contentSize.width += insets.left + insets.right
            return contentSize
        }
    }
}

class ClassesOptionsPopupVC: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Classes.count
    }
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        ClassNameVC.link = self
        TeacherNameVC.link = self
        RoomNumVC.link = self
        DaySelectVC.link = self
        self.performSegue(withIdentifier: "textfield", sender: nil)
    }
    
    static var newClass = ClassModel(Subject: "TOADS", Teacher: "MR MIKE", Room: "300", Block: "G")
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        cell.configure(with: Classes[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedRow = Classes[indexPath.row]
        LoginVC.blocks["\(ClassesOptionsPopupVC.currentBlock)"] = "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)"
//    Subject: array[0], Teacher: array[1], Room: array[2], Block
//        self.blocks[indexPath.row] = settingsBlock(blockName: "\(self.blocks[indexPath.row].blockName)", className: inputName!)
        let db = Firestore.firestore()
        let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
        currDoc.setData(LoginVC.blocks)
        if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            LoginVC.setNotifications()
        }
        self.navigationController?.popViewController(animated: true)
    }
    static var currentBlock = "G"
    public var Classes = [ClassModel]()
    private let SearchController = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        configureClasses()
        createSearchBar()
        configureTableView()
    }
    func configureClasses() {
        let db = Firestore.firestore()
        db.collection("classes").getDocuments { [self] (snapshot, error) in
            if error != nil {
                ProgressHUD.showFailed("Failed to find 'special-schedules'")
            } else {
                Classes = [ClassModel]()
                for document in (snapshot?.documents)! {
                    let fullName = document.data()["name"] as? String ?? ""
                    let array = fullName.getValues()
                    if array[3].lowercased().contains("\(ClassesOptionsPopupVC.currentBlock.lowercased())") {
                        Classes.append(ClassModel(Subject: array[0], Teacher: array[1], Room: array[2], Block: array[3]))
                    }
                }
                tableView.reloadData()
            }
        }
    }
    func configureTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
    }
    public var tableView = UITableView()
    func createSearchBar(){
        self.navigationItem.searchController = SearchController
        self.SearchController.searchBar.delegate = self
        SearchController.hidesNavigationBarDuringPresentation = false
        SearchController.searchBar.searchTextField.layer.cornerRadius = 8
        SearchController.searchBar.searchTextField.layer.masksToBounds = true
        SearchController.searchBar.tintColor = .systemBlue
        SearchController.obscuresBackgroundDuringPresentation = false
        SearchController.searchBar.placeholder = "Search for your class or add a new one"
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // filter the text
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // reset data and reload
    }
}
struct ClassModel {
    let Subject: String
    let Teacher: String
    let Room: String
    let Block: String
}

class ClassNameVC: UIViewController {
    static var link: ClassesOptionsPopupVC!
    @IBAction func pressed(_ sender: Any) {
        self.performSegue(withIdentifier: "teacher", sender: nil)
    }
    
}
class TeacherNameVC: UIViewController {
    static var link: ClassesOptionsPopupVC!
    @IBAction func pressed(_ sender: Any) {
        self.performSegue(withIdentifier: "room", sender: nil)
    }
    
}

class RoomNumVC: UIViewController {
    static var link: ClassesOptionsPopupVC!
    @IBAction func pressed(_ sender: Any) {
        self.performSegue(withIdentifier: "days", sender: nil)
    }
}

class DaySelectVC: UIViewController {
    static var link: ClassesOptionsPopupVC!
    var finalString = ""
    func checkIfExists(word: String) -> Bool {
        for selectedRow in DaySelectVC.link.Classes {
            if word == "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)" {
                return true
            }
        }
        return false
    }
    @IBAction func p(_ sender: Any) {
        let selectedRow = ClassesOptionsPopupVC.newClass
        finalString = "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)"
        if checkIfExists(word: finalString) {
            ProgressHUD.showFailed("Class already exists!")
            return
        }
        let db = Firestore.firestore()
        let currDoc = db.collection("classes").document(finalString)
        let data = ["name":"\(finalString)"]
        currDoc.setData(data)
        DaySelectVC.link.Classes.append(selectedRow)
        DaySelectVC.link.tableView.reloadData()
        self.dismiss(animated: true, completion: nil)
    }
}
