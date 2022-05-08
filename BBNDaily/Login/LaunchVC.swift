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


class LaunchVC: CustomLoader {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if FirebaseAuth.Auth.auth().currentUser != nil {
            self.gifName = "snowfall"
            self.isLarge = true
            LoginVC.setLoginInfo(weakSelf: self)
        }
        else {
            self.performSegue(withIdentifier: "NotSignedIn", sender: nil)
        }
    }
}
