//
//  ViewController.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/6/21.
//

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
//import HTMLKit
import WebKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
}

class LoginVC: UIViewController {
    static var fullName = ""
    static var email = ""
    static var phoneNum = ""
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","googlePhoto":"true","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
    static var profilePhoto = UIImageView(image: UIImage(named: "logo")!)
    @IBOutlet weak var SignInButton: GIDSignInButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        SignInButton.layer.masksToBounds = true
        SignInButton.layer.cornerRadius = 8
        SignInButton.dropShadow(scale: true, radius: 15)
    }
    static func setProfileImage(useGoogle: Bool, width: UInt) {
        if !useGoogle {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            return
        }
        let imageUrl = Auth.auth().currentUser?.photoURL?.absoluteString
        if imageUrl == nil {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
        }
        else {
            //            LoginVC.profilePhoto.downloaded(from: (Auth.auth().currentUser?.photoURL!)!)
            let imgUrl = (Auth.auth().currentUser?.photoURL!)!
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if error != nil || user == nil {
                    // Show the app's signed-out state.
                    print("failed to get user")
                } else {
                    // Show the app's signed-in state.
                    print("GOT IMAGE")
                    
                    let newurl = (user!.profile?.imageURL(withDimension: width)!)!
                    let data = NSData(contentsOf: newurl)
                    if data != nil {
                        LoginVC.profilePhoto.image = UIImage(data: data! as Data)
                    }
                    else {
                        LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
                    }
                    return
                }
            }
            let data = NSData(contentsOf: imgUrl)
            if data != nil {
                LoginVC.profilePhoto.image = UIImage(data: data! as Data)
            }
            else {
                LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            }
        }
    }
    func callTabBar() {
        self.performSegue(withIdentifier: "SignIn", sender: nil)
    }
    @IBAction func signIn(_ sender: GIDSignInButton) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) { [unowned self] user, error in
            
            if let _ = error {
                return
            }
            
            guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
            else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            
            Auth.auth().signIn(with: credential) {
                [weak self]
                result, error in
                guard let strongSelf = self else {
                    ProgressHUD.colorAnimation = UIColor(named: "red")!
                    ProgressHUD.showFailed("Invalid class")
                    return
                }
                guard error == nil else {
                    // show failed sign in
                    ProgressHUD.colorAnimation = UIColor(named: "red")!
                    ProgressHUD.showFailed("Invalid credentials")
                    return
                }
                LoginVC.fullName = (FirebaseAuth.Auth.auth().currentUser?.displayName ?? "").replacingOccurrences(of: "**", with: "")
                LoginVC.email = FirebaseAuth.Auth.auth().currentUser?.email ?? ""
                if !LoginVC.email.checkForDomain() {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.showFailed("The registered email is not a part of the BB&N domain")
                    do {
                        try FirebaseAuth.Auth.auth().signOut()
                        
                    }
                    catch {
                        return
                    }
                    return
                }
                LoginVC.phoneNum = FirebaseAuth.Auth.auth().currentUser?.phoneNumber ?? ""
                let db = Firestore.firestore()
                db.collection("users").getDocuments { (snapshot, error) in
                    if error != nil {
                        ProgressHUD.showFailed("Failed to find 'users'")
                    } else {
                        var isCreated = false
                        for document in (snapshot?.documents)! {
                            if let id = document.data()["uid"] as? String {
                                if id == FirebaseAuth.Auth.auth().currentUser?.uid {
                                    isCreated = true
                                    LoginVC.blocks = document.data()
                                    if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
                                        LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width))
                                    }
                                    else {
                                        LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width))
                                    }
//                                    if  ((LoginVC.blocks["grade"] ?? "11") as! String).contains("9") || ((LoginVC.blocks["grade"] ?? "11") as! String).contains("10") {
//                                        CalendarVC.isLunch1 = true
//                                    }
//                                    else {
//                                        CalendarVC.isLunch1 = false
//                                    }
                                    strongSelf.callTabBar()
                                    return
                                }
                            }
                        }
                        if isCreated == false {
                            LoginVC.setNotifications()
                            let db = Firestore.firestore()
                            let currDoc = db.collection("users").document("\(Auth.auth().currentUser?.uid ?? "")")
                            LoginVC.blocks["uid"] = Auth.auth().currentUser?.uid ?? ""
                            currDoc.setData(LoginVC.blocks)
                        }
                        strongSelf.callTabBar()
                    }
                }
            }
        }
    }
    static func getLunchDays() -> [[block]]{
        var monday = [block]()
        var tuesday = [block]()
        var wednesday = [block]()
        var thursday = [block]()
        var friday = [block]()
        if (LoginVC.blocks["l-monday"] as! String).lowercased().contains("2") {
            monday = CalendarVC.monday
        }
        else {
            monday = CalendarVC.mondayL1
        }
        if (LoginVC.blocks["l-tuesday"] as! String).lowercased().contains("2") {
            tuesday = CalendarVC.tuesday
        }
        else {
            tuesday = CalendarVC.tuesdayL1
        }
        if (LoginVC.blocks["l-wednesday"] as! String).lowercased().contains("2") {
            wednesday = CalendarVC.wednesday
        }
        else {
            wednesday = CalendarVC.wednesdayL1
        }
        if (LoginVC.blocks["l-thursday"] as! String).lowercased().contains("2") {
            thursday = CalendarVC.thursday
        }
        else {
            thursday = CalendarVC.thursdayL1
        }
        if (LoginVC.blocks["l-friday"] as! String).lowercased().contains("2") {
            friday = CalendarVC.friday
        }
        else {
            friday = CalendarVC.fridayL1
        }
//        if CalendarVC.isLunch1 {
//            monday = CalendarVC.mondayL1
//            tuesday = CalendarVC.tuesdayL1
//            wednesday = CalendarVC.wednesdayL1
//            thursday = CalendarVC.thursdayL1
//            friday = CalendarVC.fridayL1
//        }
//        else {
//            monday = CalendarVC.monday
//            tuesday = CalendarVC.tuesday
//            wednesday = CalendarVC.wednesday
//            thursday = CalendarVC.thursday
//            friday = CalendarVC.friday
//        }
        return [monday, tuesday, wednesday, thursday, friday]
    }
    static func setNotifications() {
        let bigArray = LoginVC.getLunchDays()
        let monday = bigArray[0]
        let tuesday = bigArray[1]
        let wednesday = bigArray[2]
        let thursday = bigArray[3]
        let friday = bigArray[4]
        for x in monday {
            // 1
            let time1 = x.reminderTime.prefix(5)
            
            let m1 = time1.replacingOccurrences(of: time1.prefix(3), with: "")
            var amOrPm1 = 0
            if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            let hours = x.reminderTime.prefix(2)
            var dateComponents = DateComponents()
            dateComponents.hour = Int(hours)! + amOrPm1
            dateComponents.minute = Int(m1)!
            dateComponents.timeZone = .current
            dateComponents.weekday = 2
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 2
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes Until \(tile)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            
            let randomIdentifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
            
            // 3
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    print("something went wrong")
                }
            }
        }
        for x in tuesday {
            // 1
            let time1 = x.reminderTime.prefix(5)
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            var amOrPm1 = 0
            if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            let hours = x.reminderTime.prefix(2)
            var dateComponents = DateComponents()
            dateComponents.hour = Int(hours)! + amOrPm1
            dateComponents.minute = Int(m1)!
            dateComponents.timeZone = .current
            dateComponents.weekday = 3
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 2
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes Until \(tile)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            
            let randomIdentifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
            
            // 3
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    print("something went wrong")
                }
            }
        }
        for x in wednesday {
            // 1
            let time1 = x.reminderTime.prefix(5)
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            var amOrPm1 = 0
            if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            let hours = x.reminderTime.prefix(2)
            var dateComponents = DateComponents()
            dateComponents.hour = Int(hours)! + amOrPm1
            dateComponents.minute = Int(m1)!
            dateComponents.timeZone = .current
            dateComponents.weekday = 4
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 2
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes Until \(tile)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            
            let randomIdentifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
            
            // 3
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    print("something went wrong")
                }
            }
        }
        for x in thursday {
            // 1
            let time1 = x.reminderTime.prefix(5)
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            var amOrPm1 = 0
            if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            let hours = x.reminderTime.prefix(2)
            var dateComponents = DateComponents()
            dateComponents.hour = Int(hours)! + amOrPm1
            dateComponents.minute = Int(m1)!
            dateComponents.timeZone = .current
            dateComponents.weekday = 5
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            //            UNCalendarNotificationTrigger(
            // 2
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes Until \(tile)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            
            let randomIdentifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
            
            // 3
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    print("something went wrong")
                }
            }
        }
        for x in friday {
            // 1
            let time1 = x.reminderTime.prefix(5)
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            var amOrPm1 = 0
            if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            let hours = x.reminderTime.prefix(2)
            var dateComponents = DateComponents()
            dateComponents.hour = Int(hours)! + amOrPm1
            dateComponents.minute = Int(m1)!
            dateComponents.timeZone = .current
            dateComponents.weekday = 6
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 2
            let content = UNMutableNotificationContent()
            content.sound = UNNotificationSound.default
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes Until \(tile)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            let randomIdentifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
            
            // 3
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    print("something went wrong")
                }
            }
        }
    }
}

extension String {
    func checkForDomain() -> Bool {
        if self.contains("bbns.org") {
            return true
        }
        return false
    }
    func getDayOfWeek() -> Int? {
        let formatter  = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let todayDate = formatter.date(from: self) else { return nil }
        let myCalendar = Calendar(identifier: .gregorian)
        let weekDay = myCalendar.component(.weekday, from: todayDate)
        return weekDay
    }
}
extension UIView {
    func dropShadow(scale: Bool = true, radius: CGFloat = 3) {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = .zero
        layer.shadowRadius = radius
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    func unbindToKeyboard() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
}

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
                    LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width))
                }
                else {
                    switcher.isOn = false
                    LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width))
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
            LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width))
            setHeader()
        }
        else {
            let db = Firestore.firestore()
            let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
            LoginVC.blocks["googlePhoto"] = "false"
            currDoc.setData(LoginVC.blocks)
            LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width))
            setHeader()
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            tableView.deselectRow(at: indexPath, animated: true)
            let alertController = UIAlertController(title: "\(blocks[indexPath.row].blockName) Block", message: "Enter your class for \(blocks[indexPath.row].blockName) block followed by the room number", preferredStyle: .alert)
            
            alertController.addTextField { (textField) in
                // configure the properties of the text field
                textField.placeholder = "e.g. Math A-370"
                textField.text = "\(self.blocks[indexPath.row].className)"
            }
            
            
            // add the buttons/actions to the view controller
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                
                // this code runs when the user hits the "save" button
                
                let inputName = alertController.textFields![0].text
                LoginVC.blocks["\(self.blocks[indexPath.row].blockName)"] = inputName
                self.blocks[indexPath.row] = settingsBlock(blockName: "\(self.blocks[indexPath.row].blockName)", className: inputName!)
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document("\(LoginVC.blocks["uid"] ?? "")")
                currDoc.setData(LoginVC.blocks)
                if ((LoginVC.blocks["notifs"] ?? "") as! String) == "true" {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    LoginVC.setNotifications()
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
            
            alertController.addAction(cancelAction)
            alertController.addAction(saveAction)
            
            present(alertController, animated: true, completion: nil)
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
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        view.addSubview(SignOutButton)
        SignOutButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        SignOutButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        SignOutButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15).isActive = true
        SignOutButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        SignOutButton.addTarget(self, action: #selector(signOut), for: .touchUpInside)
        
        blocks = [
            settingsBlock(blockName: "A", className: LoginVC.blocks["A"] as! String),
            settingsBlock(blockName: "B", className: LoginVC.blocks["B"] as! String),
            settingsBlock(blockName: "C", className: LoginVC.blocks["C"] as! String),
            settingsBlock(blockName: "D", className: LoginVC.blocks["D"] as! String),
            settingsBlock(blockName: "E", className: LoginVC.blocks["E"] as! String),
            settingsBlock(blockName: "F", className: LoginVC.blocks["F"] as! String),
            settingsBlock(blockName: "G", className: LoginVC.blocks["G"] as! String)
        ]
        
        preferenceBlocks = [
            settingsBlock(blockName: "Grade", className: "\(LoginVC.blocks["grade"] as! String)"),
            settingsBlock(blockName: "Locker #", className: "\(LoginVC.blocks["lockerNum"] as! String)"),
            settingsBlock(blockName: "Advisory Room", className: "\(LoginVC.blocks["room-advisory"] as! String)")
        ]
        
        lunchBlocks = [
            settingsBlock(blockName: "Monday Lunch", className: "\(LoginVC.blocks["l-monday"] as! String)"),
            settingsBlock(blockName: "Tuesday Lunch", className: "\(LoginVC.blocks["l-tuesday"] as! String)"),
            settingsBlock(blockName: "Wednesday Lunch", className: "\(LoginVC.blocks["l-wednesday"] as! String)"),
            settingsBlock(blockName: "Thursday Lunch", className: "\(LoginVC.blocks["l-thursday"] as! String)"),
            settingsBlock(blockName: "Friday Lunch", className: "\(LoginVC.blocks["l-friday"] as! String)")
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
    static func setToLunch2() {
        
    }
    static func setToLunch1() {
        
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
    public let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = UIColor(named: "gold")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        label.dropShadow(scale: true, radius: 50)
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

class LaunchVC: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if FirebaseAuth.Auth.auth().currentUser != nil {
            LoginVC.fullName = (FirebaseAuth.Auth.auth().currentUser?.displayName ?? "").replacingOccurrences(of: "**", with: "")
            LoginVC.email = FirebaseAuth.Auth.auth().currentUser?.email ?? ""
            if !LoginVC.email.checkForDomain() {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.showFailed("You are not a part of the BB&N domain")
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                }
                catch {
                    return
                }
                return
            }
            LoginVC.phoneNum = FirebaseAuth.Auth.auth().currentUser?.phoneNumber ?? ""
            
            let db = Firestore.firestore()
            db.collection("users").getDocuments { (snapshot, error) in
                if error != nil {
                    ProgressHUD.showFailed("Failed to find 'users'")
                } else {
                    for document in (snapshot?.documents)! {
                        if let id = document.data()["uid"] as? String {
                            if id == FirebaseAuth.Auth.auth().currentUser?.uid {
                                LoginVC.blocks = document.data()
                                if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
                                    LoginVC.setProfileImage(useGoogle: true, width: UInt(self.view.frame.width))
                                }
                                else {
                                    LoginVC.setProfileImage(useGoogle: false, width: UInt(self.view.frame.width))
                                }
                                self.callTabBar()
                                return
                            }
                        }
                    }
                    self.callTabBar()
                }
            }
            
        }
        else {
            self.performSegue(withIdentifier: "NotSignedIn", sender: nil)
        }
    }
    func callTabBar() {
        self.performSegue(withIdentifier: "SignedIn", sender: nil)
    }
}

// News
class vc3Class: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    private var newsViewModels = [NewsTableViewCellViewModel]()
    private var articles = [Article]()
    private let newsSearchVC = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        newsTableView.backgroundColor = UIColor(named: "background")
        newsTableView.dataSource = self
        newsTableView.delegate = self
        configureVC3()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsViewModels.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = newsTableView.dequeueReusableCell(withIdentifier: NewsTableViewCell.identifier,
                                                           for: indexPath
        ) as? NewsTableViewCell else {
            fatalError()
        }
        cell.newsConfigure(with: newsViewModels[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = articles[indexPath.row]
        
        guard let url = URL(string: article.url ?? "") else {
            return
        }
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        newsTableView.frame = view.bounds
        newsTableView.tableFooterView = UIView(frame: .zero)
    }
    private let newsTableView: UITableView = {
        let table = UITableView()
        table.register(NewsTableViewCell.self, forCellReuseIdentifier: NewsTableViewCell.identifier)
        return table
        
    }()
    func configureVC3(){
        view.addSubview(newsTableView)
        NewsAPICaller.shared.getTopStories { [weak self] result in
            switch result {
            
            case.success (let articles):
                self?.articles = articles
                self?.newsViewModels = articles.compactMap ({
                    NewsTableViewCellViewModel(title: $0.title, subtitle: $0.description ?? "No Description", publishedAt: $0.publishedAt, imageURL: URL(string: $0.urlToImage ?? ""))
                })
                
                DispatchQueue.main.async {
                    self?.newsTableView.reloadData()
                }
            case .failure(_):
                ProgressHUD.showFailed("Failed to get news")
            }
        }
        createSearchBar()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty else {
            return
        }
        let noSpaces = text.replacingOccurrences(of: " ", with: "+")
        NewsAPICaller.shared.search(with: noSpaces) { [weak self] result in
            switch result {
            case.success (let articles):
                self?.articles = articles
                self?.newsViewModels = articles.compactMap ({
                    NewsTableViewCellViewModel(title: $0.title, subtitle: $0.description ?? "No Description", publishedAt: $0.publishedAt, imageURL: URL(string: $0.urlToImage ?? ""))
                })
                
                DispatchQueue.main.async {
                    self?.newsTableView.reloadData()
                    self?.newsSearchVC.dismiss(animated: true, completion: nil)
                }
                
            case .failure( _):
                ProgressHUD.showFailed("Failed to get news")
            }
        }
    }
    func createSearchBar(){
        self.navigationItem.searchController = newsSearchVC
        self.newsSearchVC.searchBar.delegate = self
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.newsSearchVC.searchBar.layer.masksToBounds = true
        self.newsSearchVC.searchBar.layer.cornerRadius = 8
    }
}
final class NewsAPICaller {
    static let shared = NewsAPICaller()
    struct Constants {
        static let topHeadlinesURL = URL(string: "https://newsapi.org/v2/top-headlines?country=us&category=business&apiKey=8a4c432fe4d9472d9f4addbfc6eb5e1e")
        static let searchUrlString = "https://newsapi.org/v2/everything?sortedBy=popularity&apiKey=8a4c432fe4d9472d9f4addbfc6eb5e1e&q="
    }
    private init() {}
    
    public func getTopStories(completion: @escaping (Result<[Article], Error>) -> Void) {
        guard let url = Constants.topHeadlinesURL else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
            }
            else if let data = data {
                
                do {
                    let result = try JSONDecoder().decode(APIResponse.self, from: data)
                    completion(.success(result.articles))
                }
                catch {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
    public func search(with query: String, completion: @escaping (Result<[Article], Error>) -> Void) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let urlString = Constants.searchUrlString + query
        guard let url = URL(string: urlString) else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
            }
            else if let data = data {
                
                do {
                    let result = try JSONDecoder().decode(APIResponse.self, from: data)
                    completion(.success(result.articles))
                }
                catch {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
}

struct APIResponse: Codable {
    let articles: [Article]
}
public struct Article: Codable {
    let source: Source
    let title: String
    let description: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: String
}
struct Source: Codable {
    let name: String
}

// news tableview cell model
class NewsTableViewCellViewModel {
    let title: String
    let subtitle: String
    let publishedAt: String
    let imageURL: URL?
    var imageData: Data? = nil
    
    init(title: String,
         subtitle: String,
         publishedAt: String,
         imageURL: URL?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.publishedAt = publishedAt
        self.imageURL = imageURL
    }
}
class NewsTableViewCell: UITableViewCell {
    static let identifier = "NewsTableViewCell"
    
    private let newsTitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let subtitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 3
        label.textColor = UIColor(named: "inverse")
        label.font = .systemFont(ofSize: 12, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let DateLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "lightGray")
        label.font = .systemFont(ofSize: 10, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 6
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(named: "lightGray")
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    } ()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(newsTitleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(DateLabel)
        contentView.addSubview(newsImageView)
        contentView.backgroundColor = UIColor(named: "background")
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        newsImageView.rightAnchor.constraint(equalTo: rightAnchor, constant: -5).isActive = true
        newsImageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        newsImageView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        newsImageView.widthAnchor.constraint(equalTo: newsImageView.heightAnchor).isActive = true
        
        newsTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2).isActive = true
        newsTitleLabel.rightAnchor.constraint(equalTo: newsImageView.leftAnchor, constant: -2).isActive = true
        newsTitleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10).isActive = true
        newsTitleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -2).isActive = true
        
        subtitleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10).isActive = true
        subtitleLabel.bottomAnchor.constraint(equalTo: DateLabel.topAnchor, constant: -2).isActive = true
        subtitleLabel.rightAnchor.constraint(equalTo: newsImageView.leftAnchor, constant: -2).isActive = true
        
        DateLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 10).isActive = true
        DateLabel.rightAnchor.constraint(equalTo: newsImageView.leftAnchor, constant: -2).isActive = true
        DateLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
    }
    override func prepareForReuse(){
        super.prepareForReuse()
        newsTitleLabel.text = nil
        subtitleLabel.text = nil
        DateLabel.text = nil
        newsImageView.image = nil
    }
    func newsConfigure (with viewModel: NewsTableViewCellViewModel){
        newsTitleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        DateLabel.text = viewModel.publishedAt.stringDateFromMultipleFormats(preferredFormat: 4)
        if let data = viewModel.imageData {
            newsImageView.image = UIImage(data: data)
        }
        else if let url = viewModel.imageURL {
            URLSession.shared.dataTask(with: url) { [weak self ] data, _, error in
                guard let data = data, error == nil else {
                    return
                }
                viewModel.imageData = data
                DispatchQueue.main.async {
                    self?.newsImageView.image = UIImage(data: data)
                }
            } .resume()
        }
        
    }
}


class CalendarVC: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentDay.count
    }
    func setTimes() {
        var i = 0
        for x in currentWeekday {
            i+=1
            let time = x.reminderTime.prefix(5)
            let time1 = x.startTime.prefix(5)
            let time2 = x.endTime.prefix(5)
            let m = time.replacingOccurrences(of: time.prefix(3), with: "")
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
            var amOrPm = 0
            var amOrPm1 = 0
            var amOrPm2 = 0
            if x.reminderTime.contains("pm") && !time.prefix(2).contains("12"){
                amOrPm = 12
            }
            if x.startTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            if x.endTime.contains("pm") && !time2.prefix(2).contains("12") {
                amOrPm2 = 12
            }
            let calendar = Calendar.current
            let now = Date()
            let t = calendar.date(
                bySettingHour: (Int(time.prefix(2))!+amOrPm),
                minute: Int(m)!,
                second: 0,
                of: now)!
            let t1 = calendar.date(
                bySettingHour: (Int(time1.prefix(2))!+amOrPm1),
                minute: Int(m1)!,
                second: 0,
                of: now)!
            let t2 = calendar.date(
                bySettingHour: (Int(time2.prefix(2))!+amOrPm2),
                minute: Int(m2)!,
                second: 0,
                of: now)!
            if now.isBetweenTimeFrame(date1: t, date2: t2) {
                currentBlock = x
                //                    cell.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
                //                    cell.contentView.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
                var name = ""
                if currentBlock.block != "N/A" {
                    var className = LoginVC.blocks[currentBlock.block] as? String
                    if className == "" {
                        className = "[\(currentBlock.block) Class]"
                    }
                    name = className ?? ""
                }
                else {
                    name = "\(currentBlock.name)"
                }
                let formatter = DateComponentsFormatter()
                
                formatter.maximumUnitCount = 1
                formatter.unitsStyle = .abbreviated
                formatter.zeroFormattingBehavior = .dropAll
                formatter.allowedUnits = [.day, .hour, .minute, .second]
                if now.isBetweenTimeFrame(date1: t, date2: t1) {
                    let interval = Date().getTimeBetween(to: t1)
                    self.navigationItem.title = "\(formatter.string(from: interval)!) Until \(name)"
                    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [self] timer in
                        print("interval")
                        if interval <= 0 {
                            timer.invalidate()
                        }
                        setTimes()
                        ScheduleCalendar.reloadData()
                    }
                }
                else {
                    let interval = Date().getTimeBetween(to: t2)
                    //                    interval.
                    self.navigationItem.title = "\(formatter.string(from: interval)!) left in \(name)"
                    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [self] timer in
                        print("interval")
                        if interval <= 0 {
                            timer.invalidate()
                        }
                        setTimes()
                        ScheduleCalendar.reloadData()
                    }
                }
            }
            else {
                if currentBlock.reminderTime == x.reminderTime && i == currentWeekday.count {
                    currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n", reminderTime: "3", length: 0)
                    self.navigationItem.title = "My Schedule"
                }
            }
        }
    }
    var currentWeekday = [block]()
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        let thisBlock = currentDay[indexPath.row]
        var isLunch = true
        if !thisBlock.name.lowercased().contains("lunch") {
            isLunch = false
        }
        cell.configure(with: currentDay[indexPath.row], isLunch: isLunch)
        
        cell.selectionStyle = .none
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        if currentDate == stringDate {
            let time = currentDay[indexPath.row].reminderTime.prefix(5)
            let time1 = currentDay[indexPath.row].startTime.prefix(5)
            let time2 = currentDay[indexPath.row].endTime.prefix(5)
            let m = time.replacingOccurrences(of: time.prefix(3), with: "")
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
            var amOrPm = 0
            var amOrPm1 = 0
            var amOrPm2 = 0
            if currentDay[indexPath.row].reminderTime.contains("pm") && !time.prefix(2).contains("12"){
                amOrPm = 12
            }
            if currentDay[indexPath.row].startTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            if currentDay[indexPath.row].endTime.contains("pm") && !time2.prefix(2).contains("12") {
                amOrPm2 = 12
            }
            let calendar = Calendar.current
            let now = Date()
            let t = calendar.date(
                bySettingHour: (Int(time.prefix(2))!+amOrPm),
                minute: Int(m)!,
                second: 0,
                of: now)!
            let t1 = calendar.date(
                bySettingHour: (Int(time1.prefix(2))!+amOrPm1),
                minute: Int(m1)!,
                second: 0,
                of: now)!
            let t2 = calendar.date(
                bySettingHour: (Int(time2.prefix(2))!+amOrPm2),
                minute: Int(m2)!,
                second: 0,
                of: now)!
            if now.isBetweenTimeFrame(date1: t, date2: t2) {
                currentBlock = currentDay[indexPath.row]
                cell.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
                cell.contentView.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
            }
            else {
                cell.backgroundColor = UIColor(named: "background")
                cell.contentView.backgroundColor = UIColor(named: "background")
            }
        }
        else {
            cell.backgroundColor = UIColor(named: "background")
            cell.contentView.backgroundColor = UIColor(named: "background")
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let block = currentDay[indexPath.row]
        if block.name.lowercased().contains("lunch") {
            (tableView.cellForRow(at: indexPath) as! blockTableViewCell).animateView()
            self.performSegue(withIdentifier: "Lunch", sender: nil)
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCurrentday(date: realCurrentDate)
        ScheduleCalendar.reloadData()
        setTimes()
    }
    var currentBlock = block(name: "b4r0n", startTime: "b4r0n", endTime: "b4r0n", block: "b4r0n", reminderTime: "3", length: 0)
    static var isLunch1 = false
    var calendarIsExpanded = true
    @IBAction func switchCalendar(_ sender: UIBarButtonItem) {
        if calendarIsExpanded {
            CalendarHeightConstraint.constant = 90
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.down")
                self.view.layoutIfNeeded()
                
            }
            self.calendar.scope = .week
            calendarIsExpanded = false
        }
        else {
            self.calendar.scope = .month
            CalendarHeightConstraint.constant = height
            UIView.animate(withDuration: 0.5) {
                self.CalendarArrow.image = UIImage(systemName: "chevron.up")
                self.view.layoutIfNeeded()
            }
            calendarIsExpanded = true
        }
    }
    @IBOutlet weak var CalendarArrow: UIBarButtonItem!
    var currentDate = ""
    @IBOutlet weak var ScheduleCalendar: UITableView!
    @IBOutlet weak var calendar: FSCalendar!
    static let monday =  [
        block(name: "B", startTime: "08:15am", endTime: "09:00am", block: "B", reminderTime: "08:10am", length: 45),
        block(name: "D", startTime: "09:05am", endTime: "09:50am", block: "D", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "C", startTime: "10:40am", endTime: "11:25am", block: "C", reminderTime: "10:35am", length: 45),
        block(name: "F1", startTime: "11:30am", endTime: "12:15pm", block: "F", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A", reminderTime: "12:45pm", length: 65),
        block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "E", startTime: "02:40pm", endTime: "03:25pm", block: "E", reminderTime: "02:35pm", length: 45)
    ]
    static let mondayL1 =  [
        block(name: "B", startTime: "08:15am", endTime: "09:00am", block: "B", reminderTime: "08:10am", length: 45),
        block(name: "D", startTime: "09:05am", endTime: "09:50am", block: "D", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "C", startTime: "10:40am", endTime: "11:25am", block: "C", reminderTime: "10:35am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "F2", startTime: "12:00pm", endTime: "12:45pm", block: "F", reminderTime: "11:55am", length: 45),
        block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A", reminderTime: "12:45pm", length: 65),
        block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "E", startTime: "02:40pm", endTime: "03:25pm", block: "E", reminderTime: "02:35pm", length: 45)
    ]
    static let tuesday =  [
        block(name: "A", startTime: "08:15am", endTime: "09:00am", block: "A", reminderTime: "08:10am", length: 45),
        block(name: "F", startTime: "09:05am", endTime: "09:50am", block: "F", reminderTime: "09:00am", length: 45),
        block(name: "Wellness Break", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "Extended G", startTime: "10:20am", endTime: "11:25am", block: "G", reminderTime: "10:15am", length: 65),
        block(name: "E1", startTime: "11:30am", endTime: "12:15pm", block: "E", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended B", startTime: "12:50pm", endTime: "1:55pm", block: "B", reminderTime: "12:45pm", length: 65),
        block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "D", startTime: "02:40pm", endTime: "03:25pm", block: "D", reminderTime: "02:35pm", length: 45)
    ]
    static let tuesdayL1 =  [
        block(name: "A", startTime: "08:15am", endTime: "09:00am", block: "A", reminderTime: "08:10am", length: 45),
        block(name: "F", startTime: "09:05am", endTime: "09:50am", block: "F", reminderTime: "09:00am", length: 45),
        block(name: "Wellness Break", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "Extended G", startTime: "10:20am", endTime: "11:25am", block: "G", reminderTime: "10:15am", length: 65),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "E2", startTime: "12:00pm", endTime: "12:45pm", block: "E", reminderTime: "11:55am", length: 45),
        block(name: "Extended B", startTime: "12:50pm", endTime: "1:55pm", block: "B", reminderTime: "12:45pm", length: 65),
        block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "D", startTime: "02:40pm", endTime: "03:25pm", block: "D", reminderTime: "02:35pm", length: 45)
    ]
    static let wednesday =  [
        block(name: "G", startTime: "08:15am", endTime: "09:00am", block: "G", reminderTime: "08:10am", length: 45),
        block(name: "C", startTime: "09:05am", endTime: "09:50am", block: "C", reminderTime: "09:00am", length: 45),
        block(name: "Class Meeting", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended F", startTime: "10:20am", endTime: "11:25am", block: "F", reminderTime: "10:15am", length: 65),
        block(name: "A1", startTime: "11:30am", endTime: "12:15pm", block: "A", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Community Activity", startTime: "12:45pm", endTime: "1:25pm", block: "N/A", reminderTime: "12:40pm", length: 40)
    ]
    static let wednesdayL1 =  [
        block(name: "G", startTime: "08:15am", endTime: "09:00am", block: "G", reminderTime: "08:10am", length: 45),
        block(name: "C", startTime: "09:05am", endTime: "09:50am", block: "C", reminderTime: "09:00am", length: 45),
        block(name: "Class Meeting", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended F", startTime: "10:20am", endTime: "11:25am", block: "F", reminderTime: "10:15am", length: 65),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 45),
        block(name: "A2", startTime: "12:00pm", endTime: "12:45pm", block: "A", reminderTime: "11:55am", length: 25),
        block(name: "Community Activity", startTime: "12:45pm", endTime: "1:25pm", block: "N/A", reminderTime: "12:40pm", length: 40)
    ]
    static let thursday =  [
        block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C", reminderTime: "08:10am", length: 45),
        block(name: "B", startTime: "09:05am", endTime: "09:50am", block: "B", reminderTime: "09:00am", length: 45),
        block(name: "Advisory", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended D", startTime: "10:20am", endTime: "11:25am", block: "D", reminderTime: "10:15am", length: 45),
        block(name: "G1", startTime: "11:30am", endTime: "12:15pm", block: "G", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended E", startTime: "12:50pm", endTime: "1:55pm", block: "E", reminderTime: "12:45pm", length: 65),
        block(name: "Office Hours", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F", reminderTime: "02:35pm", length: 45)
    ]
    static let thursdayL1 =  [
        block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C", reminderTime: "08:10am", length: 45),
        block(name: "B", startTime: "09:05am", endTime: "09:50am", block: "B", reminderTime: "09:00am", length: 45),
        block(name: "Advisory", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am", length: 20),
        block(name: "Extended D", startTime: "10:20am", endTime: "11:25am", block: "D", reminderTime: "10:15am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "G2", startTime: "12:00pm", endTime: "12:45pm", block: "G", reminderTime: "11:55am", length: 45),
        block(name: "Extended E", startTime: "12:50pm", endTime: "1:55pm", block: "E", reminderTime: "12:45pm", length: 65),
        block(name: "Office Hours", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm", length: 35),
        block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F", reminderTime: "02:35pm", length: 45)
    ]
    static let friday = [
        block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E", reminderTime: "08:10am", length: 45),
        block(name: "G", startTime: "09:05am", endTime: "09:50am", block: "G", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "B", startTime: "10:40am", endTime: "11:25am", block: "B", reminderTime: "10:15am", length: 45),
        block(name: "D1", startTime: "11:30am", endTime: "12:15pm", block: "D", reminderTime: "11:25am", length: 45),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm", length: 25),
        block(name: "Extended C", startTime: "12:50pm", endTime: "1:55pm", block: "C", reminderTime: "12:45pm", length: 65),
        block(name: "A", startTime: "02:00pm", endTime: "02:45pm", block: "A", reminderTime: "01:55pm", length: 45),
        block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A", reminderTime: "02:35pm", length: 35)
    ]
    static let fridayL1 = [
        block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E", reminderTime: "08:10am", length: 45),
        block(name: "G", startTime: "09:05am", endTime: "09:50am", block: "G", reminderTime: "09:00am", length: 45),
        block(name: "Assembly", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am", length: 40),
        block(name: "B", startTime: "10:40am", endTime: "11:25am", block: "B", reminderTime: "10:15am", length: 45),
        block(name: "Lunch", startTime: "11:30am", endTime: "11:55am", block: "N/A", reminderTime: "11:25am", length: 25),
        block(name: "D2", startTime: "12:00pm", endTime: "12:45pm", block: "D", reminderTime: "11:55am", length: 45),
        block(name: "Extended C", startTime: "12:50pm", endTime: "1:55pm", block: "C", reminderTime: "12:45pm", length: 65),
        block(name: "A", startTime: "02:00pm", endTime: "02:45pm", block: "A", reminderTime: "01:55pm", length: 45),
        block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A", reminderTime: "02:35pm", length: 35)
    ]
    @IBOutlet weak var CalendarHeightConstraint: NSLayoutConstraint!
    var currentDay = [block]()
    var height = CGFloat(0)
    override func viewDidLoad() {
        super.viewDidLoad()
        ScheduleCalendar.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        height = view.frame.height/4
        CalendarHeightConstraint.constant = height
        view.layoutIfNeeded()
        ScheduleCalendar.showsVerticalScrollIndicator = false
        ScheduleCalendar.tableFooterView = UIView(frame: .zero)
        currentWeekday = setCurrentday(date: Date())
        calendar.delegate = self
        calendar.dataSource = self
        ScheduleCalendar.delegate = self
        ScheduleCalendar.dataSource = self
        //        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { results in
            for x in results {
                print("title: \(x.content.title) ")
            }
        })
        setTimes()
        //        setNotif()
    }
    func setNotif() {
        let hours = 13
        var dateComponents = DateComponents()
        dateComponents.hour = hours
        dateComponents.minute = 13
        dateComponents.second = 35
        dateComponents.timeZone = .current
        dateComponents.weekday = 6
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 2
        let content = UNMutableNotificationContent()
        content.title = "5 Minutes Until B Block"
        content.sound = UNNotificationSound.default
        
        let randomIdentifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
        
        // 3
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                print("something went wrong")
            }
        }
    }
    let vacationDates = [
        NoSchoolDay(date: "Monday, September 6, 2021", reason: "Labor Day"),
        NoSchoolDay(date: "Tuesday, September 7, 2021", reason: "Rosh Hashanah"),
        NoSchoolDay(date: "Thursday, September 16, 2021", reason: "Yom Kippur"),
        NoSchoolDay(date: "Monday, October 11, 2021", reason: "Indigenous Peoples Day"),
        NoSchoolDay(date: "Tuesday, October 12, 2021", reason: "Professional Day"),
        NoSchoolDay(date: "Thursday, November 11, 2021", reason: "Veterans Day"),
        NoSchoolDay(date: "Thursday, November 25, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Friday, November 26, 2021", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Tuesday, January 4, 2022", reason: "Thankgiving Break"),
        NoSchoolDay(date: "Monday, January 17, 2022", reason: "MLK Jr. Day"),
        NoSchoolDay(date: "Monday, February 21, 2022", reason: "Presidents Day"),
        NoSchoolDay(date: "Tuesday, February 22, 2022", reason: "Professional Day"),
        NoSchoolDay(date: "Monday, April 18, 2022", reason: "Patriots Day"),
        NoSchoolDay(date: "Monday, May 30, 2022", reason: "Memorial Day")
    ]
    var realCurrentDate = Date()
    let halfDays = [NoSchoolDay(date: "Wednesday, November 24, 2021", reason: "Thanksgiving Break Start")]
    func setCurrentday(date: Date) -> [block] {
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
        let bigArray = LoginVC.getLunchDays()
        let monday = bigArray[0]
        let tuesday = bigArray[1]
        let wednesday = bigArray[2]
        let thursday = bigArray[3]
        let friday = bigArray[4]
        switch weekDay {
        case "Monday":
            currentDay = monday
        case "Tuesday":
            currentDay = tuesday
        case "Wednesday":
            currentDay = wednesday
        case "Thursday":
            currentDay = thursday
        case "Friday":
            currentDay = friday
        default:
            currentDay = [block]()
        }
        if currentDay.isEmpty {
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy your Weekend")
        }
        else {
            ScheduleCalendar.restore()
        }
        
        for x in vacationDates {
            if stringDate.lowercased() == x.date.lowercased() {
                currentDay = [block]()
                ScheduleCalendar.restore()
                ScheduleCalendar.setEmptyMessage("No Class - \(x.reason)")
                return currentDay
            }
        }
        if date.isBetweenTimeFrame(date1: "18 Dec 2021 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Jan 2022 04:00".dateFromMultipleFormats() ?? Date()) || date.isBetweenTimeFrame(date1: "12 Mar 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "27 Mar 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = [block]()
            ScheduleCalendar.restore()
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy Break!")
            return currentDay
        }
        
        if stringDate == "Wednesday, September 8, 2021" {
            ScheduleCalendar.restore()
            currentDay = customWednesday
            return currentDay
        }
        if stringDate == "Thursday, September 9, 2021" {
            ScheduleCalendar.restore()
            currentDay = customThursday
            return currentDay
        }
        if stringDate == "Friday, September 10, 2021" {
            ScheduleCalendar.restore()
            currentDay = customFriday
            return currentDay
        }
        return currentDay
    }
    private var customWednesday = [
        block(name: "9's go to Biv", startTime: "07:30am", endTime: "08:15am", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "New 10's and 11's community", startTime: "08:15am", endTime: "09:00am", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Advisory", startTime: "09:00am", endTime: "09:35am", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Orientation Block 1", startTime: "09:40am", endTime: "10:30am", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Orientation Block 2", startTime: "10:35am", endTime: "11:25am", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Cookout Lunch", startTime: "11:30am", endTime: "12:15pm", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Orientation Block 3", startTime: "12:20pm", endTime: "01:10pm", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Orientation Block 4", startTime: "01:15pm", endTime: "02:05pm", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Advisory", startTime: "02:10pm", endTime: "02:30pm", block: "N/A", reminderTime: "07:25am", length: 45),
        block(name: "Athletics", startTime: "03:00pm", endTime: "04:30pm", block: "N/A", reminderTime: "07:25am", length: 45)
    ]
    private var customThursday = [
        block(name: "Advisory", startTime: "09:00am", endTime: "09:45am", block: "N/A", reminderTime: "08:55am", length: 45),
        block(name: "Escape Room Orientation", startTime: "09:50am", endTime: "10:40am", block: "N/A", reminderTime: "09:50am", length: 45),
        block(name: "Class Meetings", startTime: "10:45am", endTime: "11:30am", block: "N/A", reminderTime: "10:40am", length: 45),
        block(name: "Cookout Lunch", startTime: "11:30am", endTime: "12:30pm", block: "N/A", reminderTime: "11:30am", length: 45),
        block(name: "Senior Meeting, 10 and 11 on turf", startTime: "12:35pm", endTime: "01:20pm", block: "N/A", reminderTime: "12:30pm", length: 45),
        block(name: "Advisory", startTime: "01:25pm", endTime: "02:10pm", block: "N/A", reminderTime: "01:20pm", length: 45),
        block(name: "Ice Cream Truck", startTime: "02:15pm", endTime: "03:15pm", block: "N/A", reminderTime: "02:10pm", length: 45),
        block(name: "Athletics", startTime: "03:30pm", endTime: "04:30pm", block: "N/A", reminderTime: "03:15pm", length: 45),
        block(name: "Seniors Dinner", startTime: "05:30pm", endTime: "07:30pm", block: "N/A", reminderTime: "04:30pm", length: 45)
    ]
    private var customFriday = [
        block(name: "Assembly", startTime: "08:15am", endTime: "08:40am", block: "N/A", reminderTime: "08:10am", length: 45),
        block(name: "A", startTime: "08:50am", endTime: "09:20am", block: "A", reminderTime: "08:40am", length: 45),
        block(name: "B", startTime: "09:25am", endTime: "09:55am", block: "B", reminderTime: "09:20am", length: 45),
        block(name: "Break", startTime: "10:00am", endTime: "10:20am", block: "N/A", reminderTime: "09:55am", length: 45),
        block(name: "C", startTime: "10:25am", endTime: "10:55am", block: "C", reminderTime: "10:20am", length: 45),
        block(name: "D", startTime: "11:00am", endTime: "11:30am", block: "D", reminderTime: "10:55am", length: 45),
        block(name: "Lunch", startTime: "11:35am", endTime: "12:05pm", block: "N/A", reminderTime: "11:30am", length: 45),
        block(name: "E", startTime: "12:10pm", endTime: "12:40pm", block: "E", reminderTime: "12:05pm", length: 45),
        block(name: "Break", startTime: "12:45pm", endTime: "12:55pm", block: "N/A", reminderTime: "12:40pm", length: 45),
        block(name: "F", startTime: "01:00pm", endTime: "01:30pm", block: "F", reminderTime: "12:55pm", length: 45),
        block(name: "G", startTime: "01:35pm", endTime: "02:05pm", block: "G", reminderTime: "01:30pm", length: 45),
        block(name: "Advisory", startTime: "02:10pm", endTime: "02:30pm", block: "N/A", reminderTime: "02:05pm", length: 45)
    ]
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setCurrentday(date: date)
        ScheduleCalendar.reloadData()
        setTimes()
    }
}

struct block {
    let name: String
    let startTime: String
    let endTime: String
    let block: String
    let reminderTime: String
    let length: Int
}

// game plan: make calendar tableviewcell, depending on the day, configure with the coordinated day and with the correct name for the block

struct NoSchoolDay {
    let date: String
    let reason: String
}
extension UITableView {
    
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "gold")
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.sizeToFit()
        
        self.backgroundView = messageLabel
        self.separatorStyle = .none
    }
    
    func restore() {
        self.backgroundView = nil
        self.separatorStyle = .singleLine
    }
}
extension Date {
    func isBetweenTimeFrame(date1: Date, date2: Date) -> Bool {
        
        
        // In recent versions of Swift Date objectst are comparable, so you can
        // do greater than, less than, or equal to comparisons on dates without
        // needing a date extension
        
        if self > date1 && self < date2
        {
            return true
        }
        return false
    }
    func getTimeBetween(to toDate: Date) -> TimeInterval  {
        let delta = toDate.timeIntervalSince(self)
        //        let today = Date()
        return delta
        //         if delta < 0 {
        //             return today
        //         } else {
        //             return today.addingTimeInterval(delta)
        //         }
    }
    //    func getDeltaBetweenDates(to toDate: Date) -> TimeInterval  {
    //        let delta = toDate.timeIntervalSince(self)
    ////        let today = Date()
    //        return delta
    //                 if delta < 0 {
    //                     return today
    //                 } else {
    //                     return today.addingTimeInterval(delta)
    //                 }
    //    }
}
extension UITableView {
    func scrollToBottom(indexPath: IndexPath){
        DispatchQueue.main.async {
            self.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}
class blockTableViewCell: UITableViewCell {
    static let identifier = "blockTableViewCell"
    
    private let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        return label
    } ()
    private let BlockLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "lightGray")
        return label
    } ()
    private let RightLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(named: "gold")
        label.minimumScaleFactor = 0.8
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .right
        return label
    } ()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(BlockLabel)
        contentView.addSubview(RightLabel)
        contentView.backgroundColor = UIColor(named: "background")
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    var constraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        constraint = TitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10)
        constraint.isActive = true
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: RightLabel.leftAnchor, constant: -2).isActive = true
        BlockLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 10).isActive = true
        BlockLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
        RightLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        RightLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        RightLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
        
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure (with viewModel: block, isLunch: Bool){
        if viewModel.block != "N/A" {
            BlockLabel.isHidden = false
            var className = LoginVC.blocks[viewModel.block] as? String
            if className == "" {
                className = "[\(viewModel.block) Class]"
            }
            TitleLabel.text = className
            BlockLabel.text = "\(viewModel.name)"
        }
        else {
            TitleLabel.text = "\(viewModel.name)"
            if isLunch {
                BlockLabel.isHidden = false
                BlockLabel.text = "Menu Available"
            }
            else {
                if viewModel.name.lowercased().contains("advisory") {
                    TitleLabel.text = "\(viewModel.name) \(LoginVC.blocks["room-advisory"] ?? "")"
                }
                BlockLabel.isHidden = true
            }
        }
        RightLabel.text = "\(viewModel.startTime) \u{2192} \(viewModel.endTime)"
    }
}



extension String {
    func stringDateFromMultipleFormats(preferredFormat: Int) -> String? {
        let dateformatter = DateFormatter()
        let formats: [String] = [
            "yyyy-MM-dd'T'hh:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSS",
            "yyyy-MM-dd'T'hh:mm:ss.SSS",
            "yyyy-MM-dd'T'hh:mm:ss.SS",
            "yyyy-MM-dd'T'hh:mm:ss.S",
            "dd MMM yyyy HH:mm"
        ]
        dateformatter.locale = Locale(identifier: "your_loc_id")
        
        for format in formats {
            dateformatter.dateFormat = format
            if let convertedDate = dateformatter.date(from: self) {
                dateformatter.timeZone = TimeZone.current
                switch preferredFormat {
                case 0:
                    dateformatter.dateFormat = "dd MMM yyyy HH:mm"
                case 1:
                    dateformatter.dateFormat = "MM/dd/yy"
                case 2:
                    dateformatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
                case 3:
                    dateformatter.dateFormat = "dd MMM yy"
                case 4:
                    dateformatter.dateFormat = "MMM dd, yyyy"
                case 5:
                    dateformatter.dateFormat = "yyyy-MM-dd"
                default:
                    dateformatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
                }
                
                return dateformatter.string(from: convertedDate)
            }
            
        }
        return nil
    }
    func dateFromMultipleFormats() -> Date? {
        let dateFormatter = DateFormatter()
        let formats: [String] = [
            "",
            "yyyy-MM-dd'T'hh:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSS",
            "yyyy-MM-dd'T'hh:mm:ss.SSS",
            "yyyy-MM-dd'T'hh:mm:ss.SS",
            "yyyy-MM-dd'T'hh:mm:ss.S",
            "dd MMM yyyy HH:mm",
            "MMM dd yyyy"
        ]
        dateFormatter.locale = Locale(identifier: "your_loc_id")
        
        for format in formats {
            dateFormatter.dateFormat = format
            dateFormatter.timeZone = TimeZone.current
            if let convertedDate = dateFormatter.date(from: self) {
                return convertedDate
            }
            
        }
        return nil
    }
    
}

class VanguardVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    //    https://www.bbns.org/news-events/latest-news-from-bbn
    let urlString = "https://vanguard.bbns.org/category/on-campus/"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        webView.backgroundColor = UIColor.white
        view.addSubview(webView)
        webView.frame = view.bounds
        webView.navigationDelegate = self
        guard let url = URL(string: urlString) else {
            return
        }
        webView.load(URLRequest(url: url))
        showLoaderView()
    }
}
class LatestNewsVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    //    https://www.bbns.org/news-events/latest-news-from-bbn
    let urlString = "https://www.bbns.org/news-events/latest-news-from-bbn"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        webView.backgroundColor = UIColor.white
        view.addSubview(webView)
        webView.frame = view.bounds
        webView.navigationDelegate = self
        guard let url = URL(string: urlString) else {
            return
        }
        webView.load(URLRequest(url: url))
        showLoaderView()
    }
}
class AnnouncementsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return announcements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AnnouncementTableViewCell.identifier, for: indexPath) as? AnnouncementTableViewCell else {
            fatalError()
        }
        cell.backgroundColor = UIColor(named: "background")
        cell.configure(with: announcements[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }
    var announcements = [Announcement]()
    private let tableView: UITableView = {
        let tb = UITableView(frame: .zero)
        tb.backgroundColor = UIColor(named: "background")
        tb.register(AnnouncementTableViewCell.self, forCellReuseIdentifier: AnnouncementTableViewCell.identifier)
        return tb
    }()
    func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.frame = view.bounds
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.backgroundColor = UIColor(named: "background")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
    }
}
struct Announcement {
    let Title: String
    let Date: String
    let timeframe: String?
    let location: String?
    let rightIndicator: Bool
}

class AnnouncementTableViewCell: UITableViewCell {
    static let identifier = "AnnouncementTableViewCell"
    
    private let newsTitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let subtitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 6
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(named: "lightGray")
        imageView.contentMode = .scaleAspectFill
        return imageView
    } ()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(newsTitleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(newsImageView)
        contentView.backgroundColor = UIColor(named: "background")
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        newsTitleLabel.frame = CGRect(x: 10, y: 0, width: contentView.frame.size.width - 170, height: 70)
        subtitleLabel.frame = CGRect(x: 10, y: 70, width: contentView.frame.size.width - 170, height: contentView.frame.size.height/2)
        newsImageView.frame = CGRect(x: contentView.frame.size.width-150, y: 5, width: 140, height: contentView.frame.size.height-10)
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure(with viewModel: Announcement){
        newsTitleLabel.text = viewModel.Title
        subtitleLabel.text = viewModel.location ?? ""
        
    }
}
//class CustomLoader: UIViewController {
//
//    var blurImg = UIImageView()
//    var indicator = UIActivityIndicatorView()
//    var backView = UIView()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        blurImg.frame = view.bounds
//        blurImg.backgroundColor = UIColor.clear
//        blurImg.alpha = 0.5
//        indicator.style = .large
//        indicator.center = blurImg.center
//        indicator.startAnimating()
//        indicator.color = UIColor(named: "gold")
//    }
//
//    func showIndicator() {
//        DispatchQueue.main.async( execute: { [self] in
//            view.addSubview(self.blurImg)
//            view.addSubview(self.indicator)
//        })
//    }
//    func hideIndicator(){
//
//        DispatchQueue.main.async( execute:
//            {
//                self.blurImg.removeFromSuperview()
//                self.indicator.removeFromSuperview()
//        })
//    }
//}

class CustomLoader: UIViewController {
    //
    //    static let instance = CustomLoader()
    
    var viewColor: UIColor = .black
    var setAlpha: CGFloat = 0
    var gifName: String = "demo"
    
    lazy var transparentView: UIView = {
        let transparentView = UIView(frame: UIScreen.main.bounds)
        
        transparentView.backgroundColor = .clear
        transparentView.isUserInteractionEnabled = false
        return transparentView
    }()
    
    lazy var gifImage: UIImageView = {
        var gifImage = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        gifImage.contentMode = .scaleAspectFit
        gifImage.center = transparentView.center
        gifImage.isUserInteractionEnabled = false
        gifImage.loadGif(name: gifName)
        return gifImage
    }()
    
    func showLoaderView() {
        self.view.addSubview(self.transparentView)
        self.transparentView.addSubview(self.gifImage)
        self.transparentView.bringSubviewToFront(self.gifImage)
        //        UIApplication.shared.keyWindow?.addSubview(transparentView)
        
    }
    
    func hideLoaderView() {
        self.transparentView.removeFromSuperview()
    }
    
}

extension UIImageView {
    
    public func loadGif(name: String) {
        DispatchQueue.global().async {
            let image = UIImage.gif(name: name)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
    @available(iOS 9.0, *)
    public func loadGif(asset: String) {
        DispatchQueue.global().async {
            let image = UIImage.gif(asset: asset)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
}

extension UIImage {
    
    public class func gif(data: Data) -> UIImage? {
        // Create billSource from data
        guard let billSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("SwiftGif: billSource for the image does not exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(billSource)
    }
    
    public class func gif(url: String) -> UIImage? {
        // Validate URL
        guard let bundleURL = URL(string: url) else {
            print("SwiftGif: This image named \"\(url)\" does not exist")
            return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(url)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    public class func gif(name: String) -> UIImage? {
        // Check for existance of gif
        guard let bundleURL = Bundle.main
                .url(forResource: name, withExtension: "gif") else {
            print("SwiftGif: This image named \"\(name)\" does not exist")
            return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    @available(iOS 9.0, *)
    public class func gif(asset: String) -> UIImage? {
        // Create billSource from assets catalog
        guard let dataAsset = NSDataAsset(name: asset) else {
            print("SwiftGif: Cannot turn image named \"\(asset)\" into NSDataAsset")
            return nil
        }
        
        return gif(data: dataAsset.data)
    }
    
    internal class func delayForImageAtIndex(_ index: Int, billSource: CGImageSource!) -> Double {
        var delay = 0.1
        
        // Get dictionaries
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(billSource, index, nil)
        let gifPropertiesPointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 0)
        if CFDictionaryGetValueIfPresent(cfProperties, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque(), gifPropertiesPointer) == false {
            return delay
        }
        
        let gifProperties:CFDictionary = unsafeBitCast(gifPropertiesPointer.pointee, to: CFDictionary.self)
        
        // Get delay time
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as? Double ?? 0
        
        if delay < 0.01 {
            delay = 0.01 // Make sure they're not too fast
        }
        
        return delay
    }
    
    internal class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        // Check if one of them is nil
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        // Swap for modulo
        if a! < b! {
            let c = a
            a = b
            b = c
        }
        
        // Get greatest common divisor
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b! // Found it
            } else {
                a = b
                b = rest
            }
        }
    }
    
    internal class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    internal class func animatedImageWithSource(_ billSource: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(billSource)
        var images = [CGImage]()
        var delays = [Int]()
        
        // Fill arrays
        for i in 0..<count {
            // Add image
            if let image = CGImageSourceCreateImageAtIndex(billSource, i, nil) {
                images.append(image)
            }
            
            // At it's delay in cs
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            billSource: billSource)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        // Calculate full duration
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        // Get frames
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        // Heyhey
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
    }
    
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

//class LunchMenuVC: UIViewController {
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        let storage = FirebaseStorage.Storage.storage()
//        storage.reference(withPath: "lunchmenus/")
//    }
//}

class LunchMenuVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    //    let urlString = "https://firebasestorage.googleapis.com/v0/b/bbn-daily.appspot.com/o/lunchmenus%2Flunchmenu-allergy.docx?alt=media&token=3830574a-a486-419f-8eb1-2dc0bc00620c"
    override func viewDidLoad() {
        super.viewDidLoad()
        let storage = FirebaseStorage.Storage.storage()
        let reference = storage.reference(withPath: "lunchmenus/lunchmenu-allergy.docx")
        reference.downloadURL(completion: { [self] (url, error) in
            if let error = error {
                print(error)
            }
            else {
                print("the url is: \(url!.absoluteString)")
                let urlstring = url!.absoluteString
                webView.backgroundColor = UIColor.white
                view.addSubview(webView)
                webView.frame = view.bounds
                webView.navigationDelegate = self
                guard let url = URL(string: urlstring) else {
                    return
                }
                webView.load(URLRequest(url: url))
                showLoaderView()
            }
        })
        //        reference.listAll(completion: { (list, error) in
        //            if let error = error {
        //                print(error)
        //            }
        //            else {
        //                let inStorage = list.items.map({ $0.name })
        //                print(inStorage)
        //            }
        //        })
        view.backgroundColor = UIColor.white
        
    }
}
extension blockTableViewCell {
    func animateView() {
        UIView.animate(withDuration: 0.5, animations: {
            self.backgroundColor = UIColor(named: "gold-bright")?.withAlphaComponent(0.5)
            self.contentView.backgroundColor = UIColor(named: "gold-bright")?.withAlphaComponent(0.5)
        }, completion: { _ in
            self.backgroundColor = UIColor(named: "background")
            self.contentView.backgroundColor = UIColor(named: "background")
        })
    }
}

extension UIImageView {
    func downloaded(from url: URL, contentMode mode: ContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
            else {
                LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
                return
            }
            DispatchQueue.main.async() { [weak self] in
                self?.image = image
            }
        }.resume()
    }
    func downloaded(from link: String, contentMode mode: ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloaded(from: url, contentMode: mode)
    }
}
