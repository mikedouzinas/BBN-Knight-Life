//
//  LoginVC.swift
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
    static func setProfileImage(useGoogle: Bool, width: UInt, completion: @escaping (Swift.Result<UIImageView, Error>) -> Void) {
        if !useGoogle {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            completion(.success(LoginVC.profilePhoto))
            return
        }
        let imageUrl = Auth.auth().currentUser?.photoURL?.absoluteString
        if imageUrl == nil {
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            completion(.success(LoginVC.profilePhoto))
        }
        else {
            //            LoginVC.profilePhoto.downloaded(from: (Auth.auth().currentUser?.photoURL!)!)
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if error != nil || user == nil {
                    // Show the app's signed-out state.
                    let imgUrl = (Auth.auth().currentUser?.photoURL!)!
                    let data = NSData(contentsOf: imgUrl)
                    if data != nil {
                        LoginVC.profilePhoto.image = UIImage(data: data! as Data)
                    }
                    else {
                        LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
                    }
                    print("failed to get user")
                    completion(.success(LoginVC.profilePhoto))
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
                    completion(.success(LoginVC.profilePhoto))
                }
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
                                        LoginVC.setProfileImage(useGoogle: true, width: UInt(view.frame.width), completion: {_ in
                                            
                                        })
                                    }
                                    else {
                                        LoginVC.setProfileImage(useGoogle: false, width: UInt(view.frame.width), completion: {_ in
                                            
                                        })
                                    }
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
