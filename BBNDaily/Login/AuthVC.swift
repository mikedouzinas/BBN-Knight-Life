//
//  AuthVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import ProgressHUD
import Firebase
import GoogleSignIn

class AuthVC: CustomLoader {
    static var isFirstTime = true
    func signOutToken() {
        do {
            self.showLoader(text: "Signing you out...")
            try FirebaseAuth.Auth.auth().signOut()
            LoginVC.blocks = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"2nd Lunch","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","googlePhoto":"false","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            hideLoader(completion: {
                ProgressHUD.colorAnimation = .green
                ProgressHUD.showSucceed("Successfully signed out")
                if let settingsSelf = (self as? SettingsVC) {
                    settingsSelf.performSegue(withIdentifier: "Reset", sender: nil)
                }
                else {
                    self.performSegue(withIdentifier: "logOut", sender: nil)
                }
            })
        }
        catch {
            ProgressHUD.showFailed("Failed to Sign Out")
        }
    }
    
    func setAppearance(input: String?) {
        let userDefaults = UserDefaults.standard
        var preference = ""
        if let input = input {
            preference = input
            userDefaults.setValue(preference, forKey: "appearance")
        }
        else {
            preference = userDefaults.object(forKey: "appearance") as? String ?? "Match System"
        }
        let window = UIApplication.shared.keyWindow
        LoginVC.appearance = preference
        switch preference {
        case "Match System":
            window?.overrideUserInterfaceStyle = .unspecified
        case "Dark Mode":
            window?.overrideUserInterfaceStyle = .dark
        default:
            window?.overrideUserInterfaceStyle = .light
        }
    }
    func setLoginInfo(weakSelf: UIViewController?) {
        guard let strongSelf = weakSelf else {
            ProgressHUD.colorAnimation = UIColor(named: "red")!
            ProgressHUD.showFailed("Invalid class")
            return
        }
        LoginVC.fullName = (FirebaseAuth.Auth.auth().currentUser?.displayName ?? "").replacingOccurrences(of: "**", with: "")
        LoginVC.email = FirebaseAuth.Auth.auth().currentUser?.email ?? ""
        LoginVC.phoneNum = FirebaseAuth.Auth.auth().currentUser?.phoneNumber ?? ""
        let db = Firestore.firestore()
//         check if statement to use online classes or not
        db.collection("ifstatements").whereField("shouldUseOnlineClasses", isEqualTo: true).getDocuments(completion: {(snapshot, error) in
            if error != nil {
                ProgressHUD.showFailed("Failed to find 'ifstatements'")
            } else {
                if !(snapshot?.documents)!.isEmpty {
                    db.collection("default-schedules").getDocuments(completion: {(snap, err) in
                        if err != nil {
                            ProgressHUD.showFailed("Failed to find 'default schedules'")
                        }
                        else {
                            for document in (snap?.documents)! {
//                                document.documentID
                                let arrayl1 = document.data()["L1"] as? [[String: String]] ?? [[String: String]]()
                                var blocksl1 = [block]()
                                for x in arrayl1 {
                                    blocksl1.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? ""))
                                }
                                
                                let array = document.data()["L2"] as? [[String: String]] ?? [[String: String]]()
                                var blocks = [block]()
                                for x in array {
                                    blocks.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? ""))
                                }
                                print("changed!")
                                defaultSchedules["\(document.documentID)"]?.L1 = blocksl1
                                defaultSchedules["\(document.documentID)"]?.L2 = blocks
                            }
                        }
                    })
                }
                else {
                    print("false!")
                }
            }
        })
        db.collection("special-schedules").getDocuments { (snapshot, error) in
            if error != nil {
                ProgressHUD.showFailed("Failed to find 'special-schedules'")
            } else {
                var tempArray = [String: SpecialSchedule]()
//                var newArray = [String: [block]]()
//                var reasonArray = [String: String]()
//                var newArray2 = [String: [block]]()
                for document in (snapshot?.documents)! {
                    let arrayl1 = document.data()["blocks-l1"] as? [[String: String]] ?? [[String: String]]()
                    var blocksl1 = [block]()
                    for x in arrayl1 {
                        blocksl1.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? ""))
                    }
                    
                    let array = document.data()["blocks"] as? [[String: String]] ?? [[String: String]]()
                    var blocks = [block]()
                    for x in array {
                        blocks.append(block(name: x["name"] ?? "", startTime: x["startTime"] ?? "", endTime: x["endTime"] ?? "", block: x["block"] ?? ""))
                    }
                    let date = document.data()["date"] as? String ?? "N/A"
                    let reason = document.data()["reason"] as? String ?? "N/A"
                    let imageUrl = document.data()["imageUrl"] as? String ?? "N/A"
                    if blocksl1.isEmpty {
                        blocksl1 = blocks
                    }
                    tempArray[date] = SpecialSchedule(specialSchedules: blocks, specialSchedulesL1: blocksl1, reason: reason, date: date, imageUrl: imageUrl, image: nil)
                }
                LoginVC.specialSchedules = tempArray
            }
        }
        // change here to filter for the users id
        db.collection("users").whereField("uid", isEqualTo: "\(FirebaseAuth.Auth.auth().currentUser?.uid ?? "--")").getDocuments { (snapshot, error) in
            if error != nil {
                ProgressHUD.showFailed("Failed to find 'users'")
            } else {
//                var isCreated = false
                if (snapshot?.documents)!.isEmpty {
//                    print("no uid!")
                    guard let Login = (strongSelf as? LoginVC) else {
//                        print("not LoginVC")
                        self.hideLoader(completion: {
                            strongSelf.performSegue(withIdentifier: "SignedIn", sender: nil)
                        })
                        return
                    }
                    self.setNotifications()
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(Auth.auth().currentUser?.uid ?? "")")
                    LoginVC.blocks["uid"] = Auth.auth().currentUser?.uid ?? ""
                    ProgressHUD.colorAnimation = .green
                    ProgressHUD.showSucceed("Welcome to Knight Life!")
                    currDoc.setData(LoginVC.blocks)
                    weakSelf?.hideLoader(completion: {
                        Login.callTabBar()
                    })
                }
                for document in (snapshot?.documents)! {
//                    print("in documents")
                    if let id = document.data()["uid"] as? String {
                        if id == FirebaseAuth.Auth.auth().currentUser?.uid {
//                            isCreated = true
                            LoginVC.blocks = document.data()
                            let array = ["a":LoginVC.blocks["A"], "b":LoginVC.blocks["B"], "c":LoginVC.blocks["C"], "d":LoginVC.blocks["D"], "e":LoginVC.blocks["E"], "f":LoginVC.blocks["F"], "g":LoginVC.blocks["G"]]
                            var i = 0
                            let myGroup = DispatchGroup()
                            for x in array {
                                myGroup.enter()
                                guard let str: String = x.value as? String, str.contains("~"), !str.contains("/") else {
                                    i+=1
                                    myGroup.leave()
                                    continue
                                }
                                let dep = db.collection("classes").document("\(str)")
                                dep.getDocument(completion: { (snap, err)  in
                                    if error != nil {
                                        print("Failed to get class")
                                    }
                                    else {
                                        let arr = [
                                            ((snap?.data()?["monday"] as? Bool) ?? true), ((snap?.data()?["tuesday"] as? Bool) ?? true), ((snap?.data()?["wednesday"] as? Bool) ?? true), ((snap?.data()?["thursday"] as? Bool) ?? true), ((snap?.data()?["friday"] as? Bool) ?? true)]
                                        LoginVC.classMeetingDays["\(x.key)"] = arr
                                        
                                        i+=1
                                    }
                                    myGroup.leave()
                                })
                            }
                            if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
                                LoginVC.setProfileImage(useGoogle: true, width: UInt(strongSelf.view.frame.width), completion: {_ in
                                    
                                })
                            }
                            else {
                                LoginVC.setProfileImage(useGoogle: false, width: UInt(strongSelf.view.frame.width), completion: {_ in
                                })
                            }
                            myGroup.notify(queue: .main) {
                                print("Finished all requests.")
                                weakSelf?.hideLoader(completion: {
                                    guard let Login = (strongSelf as? LoginVC) else {
//                                        print("not LoginVC")
                                        strongSelf.performSegue(withIdentifier: "SignedIn", sender: nil)
                                        return
                                    }
                                    Login.callTabBar()
                                })
                            }
                            return
                        }
                    }
                }
                weakSelf?.hideLoader(completion: {
                    guard let Login = (strongSelf as? LoginVC) else {
//                        print("not LoginVC")
                        strongSelf.performSegue(withIdentifier: "SignedIn", sender: nil)
                        return
                    }
                    Login.callTabBar()
                })
            }
        }
    }
}
