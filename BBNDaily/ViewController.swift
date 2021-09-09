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
import HTMLKit
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
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","notifs":"true","uid":""]
    static var profilePhoto = UIImageView(image: UIImage(named: "logo")!)
    @IBOutlet weak var SignInButton: GIDSignInButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        SignInButton.layer.masksToBounds = true
        SignInButton.layer.cornerRadius = 8
        SignInButton.dropShadow(scale: true, radius: 15)
    }
    static func setProfileImage() {
        if LoginVC.email.lowercased().contains("veson") {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            return
        }
        let imageUrl = Auth.auth().currentUser?.photoURL?.absoluteString
        if imageUrl == nil {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
        }
        else {
            let url  = NSURL(string: imageUrl!)! as URL
            let data = NSData(contentsOf: url)
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
                LoginVC.setProfileImage()
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
    static func setNotifications() {
        for x in CalendarVC.monday {
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
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes to get to \(tile)"
            }
            else {
                content.title = "5 Minutes to get to \(x.name)"
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
        for x in CalendarVC.tuesday {
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
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes to get to \(tile)"
            }
            else {
                content.title = "5 Minutes to get to \(x.name)"
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
        for x in CalendarVC.wednesday {
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
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes to get to \(tile)"
            }
            else {
                content.title = "5 Minutes to get to \(x.name)"
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
        for x in CalendarVC.thursday {
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
            
            // 2
            let content = UNMutableNotificationContent()
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes to get to \(tile)"
            }
            else {
                content.title = "5 Minutes to get to \(x.name)"
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
        for x in CalendarVC.friday {
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
            if x.block != "N/A" {
                var tile = (LoginVC.blocks[x.block] ?? "") as! String
                if tile == "" {
                    tile = "\(x.block) Block"
                }
                content.title = "5 Minutes to get to \(tile)"
            }
            else {
                content.title = "5 Minutes to get to \(x.name)"
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
        return 1
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let backview = UIView()
        backview.backgroundColor = UIColor(named: "blue")?.withAlphaComponent(0.1)
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor(named: "blue")
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
        else {
            let cell = UITableViewCell()
            cell.backgroundColor = UIColor.white
            cell.contentView.backgroundColor = UIColor.white
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
            let alertController = UIAlertController(title: "\(blocks[indexPath.row].blockName) Block", message: "Enter your class for \(blocks[indexPath.row].blockName) block", preferredStyle: .alert)

            alertController.addTextField { (textField) in
                // configure the properties of the text field
                textField.placeholder = "e.g. Math"
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
    }
    func callReset() {
        ProgressHUD.colorAnimation = .green
        ProgressHUD.showSucceed("Successfully signed out")
        self.performSegue(withIdentifier: "Reset", sender: nil)
    }
    private var blocks = [settingsBlock]()
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
        view.backgroundColor = UIColor.white
        view.addSubview(SignOutButton)
        SignOutButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        SignOutButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        SignOutButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15).isActive = true
        SignOutButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
        SignOutButton.addTarget(self, action: #selector(signOut), for: .touchUpInside)
        
        blocks = [settingsBlock(blockName: "A", className: LoginVC.blocks["A"] as! String),
                  settingsBlock(blockName: "B", className: LoginVC.blocks["B"] as! String),
                  settingsBlock(blockName: "C", className: LoginVC.blocks["C"] as! String),
                  settingsBlock(blockName: "D", className: LoginVC.blocks["D"] as! String),
                  settingsBlock(blockName: "E", className: LoginVC.blocks["E"] as! String),
                  settingsBlock(blockName: "F", className: LoginVC.blocks["F"] as! String),
                  settingsBlock(blockName: "G", className: LoginVC.blocks["G"] as! String)]
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: SignOutButton.topAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.backgroundColor = UIColor.white
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        let button = UIButton(frame: CGRect(x: 0, y: 30, width: 30, height: 50))
        button.setTitle("Credits", for: .normal)
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
        let header = StretchyTableHeaderView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.width))
//        header.imageview.image = UIImage(named: "DefaultUserPhoto")
        header.imageview.image = LoginVC.profilePhoto.image
        header.nameLabel.text = LoginVC.fullName.capitalized
        tableView.tableHeaderView = header
    }
    @objc func openCredits() {
        print("pressed")
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
        backgroundColor = UIColor.white
        TitleLabel.text = "\(viewModel.blockName) Block"
        if viewModel.className != "" {
            DataLabel.text = viewModel.className
        }
        else {
            DataLabel.text = "[Not Set]"
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
        contentView.backgroundColor = UIColor.white
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
            LoginVC.setProfileImage()
            
            let db = Firestore.firestore()
            db.collection("users").getDocuments { (snapshot, error) in
                if error != nil {
                    ProgressHUD.showFailed("Failed to find 'users'")
                } else {
                    for document in (snapshot?.documents)! {
                        if let id = document.data()["uid"] as? String {
                            if id == FirebaseAuth.Auth.auth().currentUser?.uid {
                                LoginVC.blocks = document.data()
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
    //
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        cell.configure(with: currentDay[indexPath.row])
        
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .short
        let stringDate = formatter1.string(from: Date())
        if currentDate == stringDate {
           
            let time1 = currentDay[indexPath.row].reminderTime.prefix(5)
            let time2 = currentDay[indexPath.row].endTime.prefix(5)
            let m1 = time1.replacingOccurrences(of:  time1.prefix(3), with: "")
            let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
            var amOrPm1 = 0
            var amOrPm2 = 0
            if currentDay[indexPath.row].startTime.contains("pm") && !time1.prefix(2).contains("12"){
                amOrPm1 = 12
            }
            if currentDay[indexPath.row].endTime.contains("pm") && !time2.prefix(2).contains("12") {
                amOrPm2 = 12
            }
            let calendar = Calendar.current
            let now = Date()
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
            if now.isBetweenTimeFrame(date1: t1, date2: t2) {
                cell.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
                cell.contentView.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
            }
        }
        else {
            cell.backgroundColor = UIColor(named: "background")
            cell.contentView.backgroundColor = UIColor(named: "background")
        }
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ScheduleCalendar.reloadData()
    }
    var currentDate = ""
    @IBOutlet weak var ScheduleCalendar: UITableView!
    @IBOutlet weak var calendar: FSCalendar!
    static let monday =  [
        block(name: "B", startTime: "08:15am", endTime: "09:00am", block: "B", reminderTime: "08:10am"),
        block(name: "D", startTime: "09:05am", endTime: "09:50am", block: "D", reminderTime: "09:00am"),
        block(name: "Announcements/Special Programs", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am"),
        block(name: "C", startTime: "10:40am", endTime: "11:25am", block: "C", reminderTime: "10:35am"),
        block(name: "F1", startTime: "11:30am", endTime: "12:15pm", block: "F", reminderTime: "11:25am"),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm"),
        block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A", reminderTime: "12:45pm"),
        block(name: "Community Activity Block", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm"),
        block(name: "E", startTime: "02:40pm", endTime: "03:25pm", block: "E", reminderTime: "02:35pm")
    ]
    static let tuesday =  [
        block(name: "A", startTime: "08:15am", endTime: "09:00am", block: "A", reminderTime: "08:10am"),
        block(name: "F", startTime: "09:05am", endTime: "09:50am", block: "F", reminderTime: "09:00am"),
        block(name: "Wellness Break", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am"),
        block(name: "Extended G", startTime: "10:20am", endTime: "11:25am", block: "G", reminderTime: "10:15am"),
        block(name: "E1", startTime: "11:30am", endTime: "12:15pm", block: "E", reminderTime: "11:25am"),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm"),
        block(name: "Extended B", startTime: "12:50pm", endTime: "1:55pm", block: "B", reminderTime: "12:45pm"),
        block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm"),
        block(name: "D", startTime: "02:40pm", endTime: "03:25pm", block: "D", reminderTime: "02:35pm")
    ]
    static let wednesday =  [
        block(name: "G", startTime: "08:15am", endTime: "09:00am", block: "G", reminderTime: "08:10am"),
        block(name: "C", startTime: "09:05am", endTime: "09:50am", block: "C", reminderTime: "09:00am"),
        block(name: "Class Meeting", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am"),
        block(name: "Extended F", startTime: "10:20am", endTime: "11:25am", block: "F", reminderTime: "10:15am"),
        block(name: "A1", startTime: "11:30am", endTime: "12:15pm", block: "A", reminderTime: "11:25am"),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm"),
        block(name: "Odd Week: CAB, Even Week: Faculty Time", startTime: "12:45pm", endTime: "1:25pm", block: "N/A", reminderTime: "12:45pm")
    ]
    static let thursday =  [
        block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C", reminderTime: "08:10am"),
        block(name: "B", startTime: "09:05am", endTime: "09:50am", block: "B", reminderTime: "09:00am"),
        block(name: "Advisory", startTime: "09:55am", endTime: "10:15am", block: "N/A", reminderTime: "09:50am"),
        block(name: "Extended D", startTime: "10:20am", endTime: "11:25am", block: "D", reminderTime: "10:15am"),
        block(name: "G1", startTime: "11:30am", endTime: "12:15pm", block: "G", reminderTime: "11:25am"),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm"),
        block(name: "Extended E", startTime: "12:50pm", endTime: "1:55pm", block: "E", reminderTime: "12:45pm"),
        block(name: "Office Hours", startTime: "02:00pm", endTime: "02:35pm", block: "N/A", reminderTime: "01:55pm"),
        block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F", reminderTime: "02:35pm")
    ]
    static let friday = [
        block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E", reminderTime: "08:10am"),
        block(name: "G", startTime: "09:05am", endTime: "09:50am", block: "G", reminderTime: "09:00am"),
        block(name: "Announcements/Special Programs", startTime: "09:55am", endTime: "10:35am", block: "N/A", reminderTime: "09:50am"),
        block(name: "B", startTime: "10:40am", endTime: "11:25am", block: "B", reminderTime: "10:15am"),
        block(name: "D1", startTime: "11:30am", endTime: "12:15pm", block: "D", reminderTime: "11:25am"),
        block(name: "Lunch", startTime: "12:20pm", endTime: "12:45pm", block: "N/A", reminderTime: "12:15pm"),
        block(name: "Extended C", startTime: "12:50pm", endTime: "1:55pm", block: "C", reminderTime: "12:45pm"),
        block(name: "A", startTime: "02:00pm", endTime: "02:45pm", block: "A", reminderTime: "01:55pm"),
        block(name: "Community Activity Block", startTime: "02:50pm", endTime: "03:25pm", block: "N/A", reminderTime: "02:35pm")
    ]
    @IBOutlet weak var CalendarHeightConstraint: NSLayoutConstraint!
    var currentDay = [block]()
    override func viewDidLoad() {
        super.viewDidLoad()
        ScheduleCalendar.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        ScheduleCalendar.backgroundColor = UIColor(named: "background")
        CalendarHeightConstraint.constant = view.frame.height/4
        view.layoutIfNeeded()
        ScheduleCalendar.showsVerticalScrollIndicator = false
        ScheduleCalendar.tableFooterView = UIView(frame: .zero)
        setCurrentday(date: Date())
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
//        setNotif()
    }
    func setNotif() {
        let hours = 18
        var dateComponents = DateComponents()
        dateComponents.hour = hours
        dateComponents.minute = 12
        dateComponents.timeZone = .current
        dateComponents.weekday = 4
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // 2
        let content = UNMutableNotificationContent()
        content.title = "5 Minutes to get to B Block"
//        content.body = "BB&N Daily"

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
    
    let halfDays = [NoSchoolDay(date: "Wednesday, November 24, 2021", reason: "Thanksgiving Break Start")]
    func setCurrentday(date: Date) {
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
            currentDay = CalendarVC.monday
        case "Tuesday":
            currentDay = CalendarVC.tuesday
        case "Wednesday":
            currentDay = CalendarVC.wednesday
        case "Thursday":
            currentDay = CalendarVC.thursday
        case "Friday":
            currentDay = CalendarVC.friday
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
                return
            }
        }
        if date.isBetweenTimeFrame(date1: "18 Dec 2021 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Jan 2022 04:00".dateFromMultipleFormats() ?? Date()) || date.isBetweenTimeFrame(date1: "12 Mar 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "27 Mar 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = [block]()
            ScheduleCalendar.restore()
            ScheduleCalendar.setEmptyMessage("No Class - Enjoy Break!")
            return
        }
        
        if stringDate == "Wednesday, September 8, 2021" {
            ScheduleCalendar.restore()
            currentDay = customWednesday
            return
        }
        if stringDate == "Thursday, September 9, 2021" {
            ScheduleCalendar.restore()
            currentDay = customThursday
            return
        }
        if stringDate == "Friday, September 10, 2021" {
            ScheduleCalendar.restore()
            currentDay = customFriday
            return
        }
    }
    private var customWednesday = [
        block(name: "9's go to Biv", startTime: "07:30am", endTime: "08:15am", block: "N/A", reminderTime: "07:25am"),
        block(name: "New 10's and 11's community", startTime: "08:15am", endTime: "09:00am", block: "N/A", reminderTime: "07:25am"),
        block(name: "Advisory", startTime: "09:00am", endTime: "09:35am", block: "N/A", reminderTime: "07:25am"),
        block(name: "Orientation Block 1", startTime: "09:40am", endTime: "10:30am", block: "N/A", reminderTime: "07:25am"),
        block(name: "Orientation Block 2", startTime: "10:35am", endTime: "11:25am", block: "N/A", reminderTime: "07:25am"),
block(name: "Cookout Lunch", startTime: "11:30am", endTime: "12:15pm", block: "N/A", reminderTime: "07:25am"),
        block(name: "Orientation Block 3", startTime: "12:20pm", endTime: "01:10pm", block: "N/A", reminderTime: "07:25am"),
        block(name: "Orientation Block 4", startTime: "01:15pm", endTime: "02:05pm", block: "N/A", reminderTime: "07:25am"),
        block(name: "Advisory", startTime: "02:10pm", endTime: "02:30pm", block: "N/A", reminderTime: "07:25am"),
        block(name: "Athletics", startTime: "03:00pm", endTime: "04:30pm", block: "N/A", reminderTime: "07:25am")
    ]
    private var customThursday = [
        block(name: "Advisory", startTime: "09:00am", endTime: "09:45am", block: "N/A", reminderTime: "08:55am"),
        block(name: "Escape Room Orientation", startTime: "09:50am", endTime: "10:40am", block: "N/A", reminderTime: "09:50am"),
        block(name: "Class Meetings", startTime: "10:45am", endTime: "11:30am", block: "N/A", reminderTime: "10:40am"),
        block(name: "Cookout Lunch", startTime: "11:30am", endTime: "12:30pm", block: "N/A", reminderTime: "11:30am"),
        block(name: "Senior Meeting, 10 and 11 on turf", startTime: "12:35pm", endTime: "01:20pm", block: "N/A", reminderTime: "12:30pm"),
        block(name: "Advisory", startTime: "01:25pm", endTime: "02:10pm", block: "N/A", reminderTime: "01:20pm"),
        block(name: "Ice Cream Truck", startTime: "02:15pm", endTime: "03:15pm", block: "N/A", reminderTime: "02:10pm"),
        block(name: "Athletics", startTime: "03:30pm", endTime: "04:30pm", block: "N/A", reminderTime: "03:15pm"),
        block(name: "Seniors Dinner", startTime: "05:30pm", endTime: "07:30pm", block: "N/A", reminderTime: "04:30pm")
    ]
    private var customFriday = [
        block(name: "Assembly", startTime: "08:15am", endTime: "08:40am", block: "N/A", reminderTime: "08:10am"),
        block(name: "A", startTime: "08:50am", endTime: "09:20am", block: "A", reminderTime: "08:40am"),
        block(name: "B", startTime: "09:25am", endTime: "09:55am", block: "B", reminderTime: "09:20am"),
        block(name: "Break", startTime: "10:00am", endTime: "10:20am", block: "N/A", reminderTime: "09:55am"),
        block(name: "C", startTime: "10:25am", endTime: "10:55am", block: "C", reminderTime: "10:20am"),
        block(name: "D", startTime: "11:00am", endTime: "11:30am", block: "D", reminderTime: "10:55am"),
        block(name: "Lunch", startTime: "11:35am", endTime: "12:05pm", block: "N/A", reminderTime: "11:30am"),
        block(name: "E", startTime: "12:10pm", endTime: "12:40pm", block: "E", reminderTime: "12:05pm"),
        block(name: "Break", startTime: "12:45pm", endTime: "12:55pm", block: "N/A", reminderTime: "12:40pm"),
        block(name: "F", startTime: "01:00pm", endTime: "01:30pm", block: "F", reminderTime: "12:55pm"),
        block(name: "G", startTime: "01:35pm", endTime: "2:05pm", block: "G", reminderTime: "01:30pm"),
        block(name: "Advisory", startTime: "02:10pm", endTime: "2:30pm", block: "N/A", reminderTime: "02:05pm")
    ]
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        setCurrentday(date: date)
        ScheduleCalendar.reloadData()
    }
}

struct block {
    let name: String
    let startTime: String
    let endTime: String
    let block: String
    let reminderTime: String
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
        
        if self >= date1 && self <= date2
        {
            return true
        }
        return false
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
        label.textColor = UIColor(named: "gold-light")
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
    func configure (with viewModel: block){
        if viewModel.block != "N/A" {
            BlockLabel.isHidden = false
            var className = LoginVC.blocks[viewModel.block] as? String
            if className == "" {
                className = "[\(viewModel.block) Class]"
            }
            TitleLabel.text = className
        }
        else {
            BlockLabel.isHidden = true
            TitleLabel.text = "\(viewModel.name)"
        }
        BlockLabel.text = "\(viewModel.name)"
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
