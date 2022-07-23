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
    static var blocks: [String: Any] = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"2nd Lunch","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","googlePhoto":"false","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
    static var specialSchedules = [String: SpecialSchedule]()
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
            LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", gradientColors: (top: UIColor(named: "gold")!, bottom: UIColor(named: "blue")!), circular: false, textAttributes: nil)
            completion(.success(LoginVC.profilePhoto))
        }
        else {
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
//    static var isCreated = false
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
            showLoader(text: "Signing you in...")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            
            Auth.auth().signIn(with: credential) {
                [weak self]
                result, error in
                
                guard error == nil else {
                    // show failed sign in
                    self?.hideLoader(completion: {
                        ProgressHUD.colorAnimation = UIColor(named: "red")!
                        ProgressHUD.showFailed("Invalid credentials")
                    })
                    
                    return
                }
                self?.setLoginInfo(weakSelf: self)
            }
        }
    }
    static var classMeetingDays = ["a":[true, true, true, true, true],"b":[true, true, true, true, true],"c":[true, true, true, true, true],"d":[true, true, true, true, true],"e":[true, true, true, true, true], "f":[true, true, true, true, true], "g":[true, true, true, true, true]]
    static var upcomingDays = [CustomWeekday]()
}

