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


class LaunchVC: AuthVC {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        getTotalKnightLifeUsers()
        setAppearance(input: nil)
        if FirebaseAuth.Auth.auth().currentUser != nil {
            checkSeason()
            setLoginInfo(weakSelf: self)
        }
        else {
            self.performSegue(withIdentifier: "NotSignedIn", sender: nil)
        }
    }
    func checkSeason() {
        for season in seasons {
            if Date() < season.Date {
                print("found one")
                self.gifName = season.gifName
                self.isLarge = true
                if season.gifName == "summer" || season.gifName == "halloween" {
                    self.isLarge = false
                }
                else if gifName == "snowfall" {
                    if Date().isBetweenTimeFrame(date1: "14 Feb".startOrEndDate(isStart: true, year: "current") ?? Date(), date2: "14 Feb".startOrEndDate(isStart: false, year: "current") ?? Date()) {
                        gifName = "hearts"
                        isLarge = false
                    }
                }
                showLoaderView()
                return
            }
        }
    }
    
}
struct Season {
    let Date: Date
    let gifName: String
}
let seasons = [Season(Date: "19 Mar".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "snowfall"), Season(Date: "31 May".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "spring"), Season(Date: "31 Aug".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "summer"), Season(Date: "30 Sep".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "fall"), Season(Date: "31 Oct".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "halloween"), Season(Date: "1 Dec".startOrEndDate(isStart: true, year: "current") ?? Date(), gifName: "fall"), Season(Date: "31 Dec".startOrEndDate(isStart: false, year: "current") ?? Date(), gifName: "snowfall")]
