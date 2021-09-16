//
//  LaunchVC.swift
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
                }
            }
            db.collection("users").getDocuments { (snapshot, error) in
                if error != nil {
                    ProgressHUD.showFailed("Failed to find 'users'")
                } else {
                    for document in (snapshot?.documents)! {
                        if let id = document.data()["uid"] as? String {
                            if id == FirebaseAuth.Auth.auth().currentUser?.uid {
                                LoginVC.blocks = document.data()
                                if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
                                    LoginVC.setProfileImage(useGoogle: true, width: UInt(self.view.frame.width), completion: {_ in
                                        
                                    })
                                }
                                else {
                                    LoginVC.setProfileImage(useGoogle: false, width: UInt(self.view.frame.width), completion: {_ in
                                    })
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
