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
        setAppearance(input: nil)
        if FirebaseAuth.Auth.auth().currentUser != nil {
            self.gifName = "snowfall"
            self.isLarge = true
            showLoader(text: "Signing you in...")
            setLoginInfo(weakSelf: self)
        }
        else {
            self.performSegue(withIdentifier: "NotSignedIn", sender: nil)
        }
    }
}
