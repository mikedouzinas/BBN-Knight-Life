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
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"2nd Lunch","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","l-a":"","l-b":"","l-c":"","l-d":"","l-e":"","l-f":"","l-g":"","googlePhoto":"false","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
    static var specialSchedules = [String: SpecialSchedule]()
    static var specialDays = [String: Day]()
    static var breaks = [Break]()
    // nil until read, and nil is meaningful: it means the app does not know the school
    // year, so it must not claim a day is outside it. See Term in Structs.swift.
    static var term: Term?
    static var profilePhoto = UIImageView(image: UIImage(named: "logo")!)
    // Whether this account may publish schedules. Set from the admins collection in
    // Firestore, which is the same source the security rules read, so the button and the
    // permission can never disagree. Defaults to false until the lookup answers.
    static var isAdmin = false

    /// Week keys ("M/d" of that week's Monday) that have a usable lunch menu, read once from
    /// `schedules/menus`. Empty until the lookup answers.
    ///
    /// Without this the app offered "Press for menu" on every lunch block, pushed the menu
    /// screen, found no URL for the week, and bounced straight back out with "Menu not
    /// available". The menus document was last written 2026-03-02, so every week since has
    /// behaved that way.
    static var lunchMenuWeeks = Set<String>()

    /// The "M/d" key for the Monday of the week containing `date`. Matches how LunchMenuVC
    /// looks the menu up, so the two cannot disagree about which week it is.
    static func lunchMenuWeekKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let weekday = Calendar.current.component(.weekday, from: date)
        let monday = Calendar.current.date(byAdding: .day, value: -(weekday - 2), to: date) ?? date
        return formatter.string(from: monday)
    }

    /// Whether there is a menu worth offering for the week containing `date`. False while the
    /// lookup is still in flight, so the app stays quiet rather than promising a menu it cannot
    /// show. The calendar refreshes on a timer, so it appears as soon as the data lands.
    static func hasLunchMenu(for date: Date = Date()) -> Bool {
        lunchMenuWeeks.contains(lunchMenuWeekKey(for: date))
    }
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
    static var upcomingDays = [ResolvedDay]()
}

