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

class LoginVC: AuthVC {
    static var fullName = ""
    static var email = ""
    static var phoneNum = ""
    static var defaultBlocks = [String: [String: [block]]]()
    static var appearance = ""
    static var busNumber = 16175930396
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"2nd Lunch","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","l-a":"Not Set","l-b":"Not Set","l-c":"Not Set","l-d":"Not Set","l-e":"Not Set","l-f":"Not Set","l-g":"Not Set","googlePhoto":"false","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
    static var specialSchedules = [String: SpecialSchedule]()
    static var specialDays = [String: Day]()
    static var breaks = [Break]()
    static var profilePhoto = UIImageView(image: UIImage(named: "logo")!)
    @IBOutlet weak var SignInButton: GIDSignInButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        SignInButton.layer.masksToBounds = true
        SignInButton.layer.cornerRadius = 8
        SignInButton.dropShadow(scale: true, radius: 15)
    }
//    static var isCreated = false
    func callTabBar() {
        self.performSegue(withIdentifier: "SignIn", sender: nil)
    }
    @IBAction func signIn(_ sender: GIDSignInButton) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
            
            if let _ = error {
                return
            }
            
            guard let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                return
            }
            showLoader(text: "Signing you in...")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) {
                [weak self]
                result, error in
                
                guard error == nil else {
                    // show failed sign in
                    self?.hideLoader(completion: {
                        ProgressHUD.colorAnimation = UIColor(named: "red")!
                        ProgressHUD.failed("Invalid credentials")
                    })
                    
                    return
                }
                self?.setLoginInfo()
            }
        }
    }
    static var classMeetingDays = ["a":[true, true, true, true, true],"b":[true, true, true, true, true],"c":[true, true, true, true, true],"d":[true, true, true, true, true],"e":[true, true, true, true, true], "f":[true, true, true, true, true], "g":[true, true, true, true, true]]
    static var upcomingDays = [CustomWeekday]()
}

