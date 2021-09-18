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
import GoogleMaps


class LoginVC: UIViewController {
    static var fullName = ""
    static var email = ""
    static var phoneNum = ""
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","googlePhoto":"true","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
    static var specialSchedules = [String: [block]]()
    static var specialSchedulesL1 = [String: [block]]()
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
//            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", gradientColors: (top: UIColor(named: "gold")!, bottom: UIColor(named: "blue")!), circular: false, textAttributes: nil)
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
                db.collection("special-schedules").getDocuments { (snapshot, error) in
                    if error != nil {
                        ProgressHUD.showFailed("Failed to find 'special-schedules'")
                    } else {
                        //                var isCreated = false
                        var newArray = [String: [block]]()
                        for document in (snapshot?.documents)! {
//                            documen
                            let array = document.data()["blocks"] as? [[String: String]] ?? [[String: String]]()
                            var blocks = [block]()
                            for x in array {
                                blocks.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? "", reminderTime: x["reminderTime"] ?? "", length: 0))
                            }
                            newArray[document.data()["date"] as? String ?? ""] = blocks
                        }
                        LoginVC.specialSchedules = newArray
                        var newArray2 = [String: [block]]()
                        for document in (snapshot?.documents)! {
//                            documen
                            let array = document.data()["blocks-l1"] as? [[String: String]] ?? [[String: String]]()
                            var blocks = [block]()
                            for x in array {
                                blocks.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? "", reminderTime: x["reminderTime"] ?? "", length: 0))
                            }
                            newArray2[document.data()["date"] as? String ?? ""] = blocks
                        }
                        LoginVC.specialSchedulesL1 = newArray2
                        for x in LoginVC.specialSchedulesL1 {
                            if x.value.isEmpty {
                                LoginVC.specialSchedulesL1[x.key] = LoginVC.specialSchedules[x.key]
                            }
                        }
                    }
                }
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
    static func getLunchDays() -> [[block]] {
        var monday = [block]()
        var tuesday = [block]()
        var wednesday = [block]()
        var thursday = [block]()
        var friday = [block]()
        if ((LoginVC.blocks["l-monday"] as? String) ?? "").lowercased().contains("2") {
            monday = CalendarVC.monday
        }
        else {
            monday = CalendarVC.mondayL1
        }
        if ((LoginVC.blocks["l-tuesday"] as? String) ?? "").lowercased().contains("2") {
            tuesday = CalendarVC.tuesday
        }
        else {
            tuesday = CalendarVC.tuesdayL1
        }
        if ((LoginVC.blocks["l-wednesday"] as? String) ?? "").lowercased().contains("2") {
            wednesday = CalendarVC.wednesday
        }
        else {
            wednesday = CalendarVC.wednesdayL1
        }
        if ((LoginVC.blocks["l-thursday"] as? String) ?? "").lowercased().contains("2") {
            thursday = CalendarVC.thursday
        }
        else {
            thursday = CalendarVC.thursdayL1
        }
        if ((LoginVC.blocks["l-friday"] as? String) ?? "").lowercased().contains("2") {
            friday = CalendarVC.friday
        }
        else {
            friday = CalendarVC.fridayL1
        }
        return [monday, tuesday, wednesday, thursday, friday]
    }
    static func findArray(date: Date) -> CustomWeekday {
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .full
        let stringDate = formatter1.string(from: date)
        var currentDay = [block]()
        print(stringDate)
        let bigArray = LoginVC.getLunchDays()
        let monday = bigArray[0]
        let tuesday = bigArray[1]
        let wednesday = bigArray[2]
        let thursday = bigArray[3]
        let friday = bigArray[4]
        let index = stringDate.firstIndex(of: ",")
        let weekday = stringDate.prefix(upTo: index!).lowercased()
        switch weekday {
        case "monday":
            currentDay = monday
        case "tuesday":
            currentDay = tuesday
        case "wednesday":
            currentDay = wednesday
        case "thursday":
            currentDay = thursday
        case "friday":
            currentDay = friday
        default:
            currentDay = [block]()
        }
        
        for x in CalendarVC.vacationDates {
            if stringDate.lowercased() == x.date.lowercased() {
                currentDay = [block]()
                return CustomWeekday(blocks: currentDay, weekday: String(weekday))
            }
        }
        if date.isBetweenTimeFrame(date1: "18 Dec 2021 04:00".dateFromMultipleFormats() ?? Date(), date2: "02 Jan 2022 04:00".dateFromMultipleFormats() ?? Date()) || date.isBetweenTimeFrame(date1: "12 Mar 2022 04:00".dateFromMultipleFormats() ?? Date(), date2: "27 Mar 2022 04:00".dateFromMultipleFormats() ?? Date()) {
            currentDay = [block]()
            return CustomWeekday(blocks: currentDay, weekday: String(weekday))
        }
        for x in LoginVC.specialSchedules {
            if x.key.lowercased() == stringDate.lowercased() {
                currentDay = x.value
                if !((LoginVC.blocks["l-\(weekday)"] as? String) ?? "").lowercased().contains("2") {
                    let obj = LoginVC.specialSchedulesL1[x.key]
                    return CustomWeekday(blocks: obj ?? [block](), weekday: String(weekday))
                }
                return CustomWeekday(blocks: currentDay, weekday: String(weekday))
            }
        }
        return CustomWeekday(blocks: currentDay, weekday: String(weekday))
    }
    static func addNotif(x: block, weekDay: String) {
        let time1 = x.reminderTime.prefix(5)
        
        let m1 = time1.replacingOccurrences(of: time1.prefix(3), with: "")
        var amOrPm1 = 0
        if x.reminderTime.contains("pm") && !time1.prefix(2).contains("12"){
            amOrPm1 = 12
        }
        let hours = x.reminderTime.prefix(2)
        var dateComponents = DateComponents()
        dateComponents.hour = (Int(hours ) ?? 0) + amOrPm1
        dateComponents.minute = (Int(m1) ?? 0)
        dateComponents.timeZone = .current
        
        var weekNum = 1
        switch weekDay {
        case "sunday":
            weekNum = 1
        case "monday":
            weekNum = 2
        case "tuesday":
            weekNum = 3
        case "wednesday":
            weekNum = 4
        case "thursday":
            weekNum = 5
        case "friday":
            weekNum = 6
        default:
            weekNum = 7
        }
        dateComponents.weekday = weekNum
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
    static var todayArray: CustomWeekday!
    static var twoDaysArray: CustomWeekday!
    static var threeDaysArray: CustomWeekday!
    static var fourDaysArray: CustomWeekday!
    static var fiveDaysArray: CustomWeekday!
    static var sixDaysArray: CustomWeekday!
    static var sevenDaysArray: CustomWeekday!
    static var bigArray = [CustomWeekday]()
    static func setNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let today = Date()
        let twoDays = calendar.date(byAdding: .day, value: 1, to: Date())!
        let threeDays = calendar.date(byAdding: .day, value: 2, to: Date())!
        let fourDays = calendar.date(byAdding: .day, value: 3, to: Date())!
        let fiveDays = calendar.date(byAdding: .day, value: 4, to: Date())!
        let sixDays = calendar.date(byAdding: .day, value: 5, to: Date())!
        let sevenDays = calendar.date(byAdding: .day, value: 6, to: Date())!
        
        LoginVC.todayArray = LoginVC.findArray(date: today)
        LoginVC.twoDaysArray = LoginVC.findArray(date: twoDays)
        LoginVC.threeDaysArray = LoginVC.findArray(date: threeDays)
        LoginVC.fourDaysArray = LoginVC.findArray(date: fourDays)
        LoginVC.fiveDaysArray = LoginVC.findArray(date: fiveDays)
        LoginVC.sixDaysArray = LoginVC.findArray(date: sixDays)
        LoginVC.sevenDaysArray = LoginVC.findArray(date: sevenDays)
        bigArray = [todayArray, twoDaysArray, threeDaysArray, fourDaysArray, fiveDaysArray, sixDaysArray, sevenDaysArray]
        for x in todayArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(todayArray.weekday)")
            addNotif(x: x, weekDay: todayArray.weekday)
        }
        print("\n")
        for x in twoDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(twoDaysArray.weekday)")
            addNotif(x: x, weekDay: twoDaysArray.weekday)
        }
        print("\n")
        for x in threeDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(threeDaysArray.weekday)")
            addNotif(x: x, weekDay: threeDaysArray.weekday)
        }
//        print("\n")
        for x in fourDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(fourDaysArray.weekday)")
            addNotif(x: x, weekDay: fourDaysArray.weekday)
        }
        print("\n")
        for x in fiveDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(fiveDaysArray.weekday)")
            addNotif(x: x, weekDay: fiveDaysArray.weekday)
        }
        print("\n")
        for x in sixDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(sixDaysArray.weekday)")
            addNotif(x: x, weekDay: sixDaysArray.weekday)
        }
        print("\n")
        for x in sevenDaysArray.blocks {
//            var title = ""
//            if x.block != "N/A" {
//                var tile = (LoginVC.blocks[x.block] ?? "") as! String
//                if tile == "" {
//                    tile = "\(x.block) Block"
//                }
//                title = "5 Minutes Until \(tile)"
//            }
//            else {
//                title = "5 Minutes Until \(x.name)"
//            }
//            print("notifs for \(title) in \(sevenDaysArray.weekday)")
            addNotif(x: x, weekDay: sevenDaysArray.weekday)
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { results in
            for x in results {
                print("title: \(x.content.title)")
            }
        })
    }
}

struct CustomWeekday {
    let blocks: [block]
    let weekday: String
}
