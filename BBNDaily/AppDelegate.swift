//
//  AppDelegate.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/6/21.
//

import UIKit
import Firebase
import FirebaseMessaging
import GoogleSignIn
import GoogleUtilities
import GoogleDataTransport
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UIWindowSceneDelegate, MessagingDelegate {
    let notificationCenter = UNUserNotificationCenter.current()
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        
        requestAuthForNotifications()
        application.registerForRemoteNotifications()
        let attributes = [NSAttributedString.Key.font:UIFont(name: "TimesNewRomanPSMT", size: 10)]
        UITabBarItem.appearance().setTitleTextAttributes(attributes as [NSAttributedString.Key : Any], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(attributes as [NSAttributedString.Key : Any], for: .selected)
//        GIDSignIn.sharedInstance.clientID = FirebaseApp.app()?.options.clientID
        return true
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { token, _ in
            guard let token = token else {
                return
            }
            print("Token \(token)")
        }
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print("got one")
        return UIBackgroundFetchResult.newData
    }
    func requestAuthForNotifications(){
        notificationCenter.delegate = self
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        notificationCenter.requestAuthorization(options: options) { (didAllow, error) in
            if !didAllow {
                print("User has declined notification")
            }
        }
        
    }
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any])
      -> Bool {
      return GIDSignIn.sharedInstance.handle(url)
    }
    func changeTheme(themeVal: String) {
      if #available(iOS 13.0, *) {
         switch themeVal {
         case "dark":
             window?.overrideUserInterfaceStyle = .dark
             break
         case "light":
             window?.overrideUserInterfaceStyle = .light
             break
         default:
             window?.overrideUserInterfaceStyle = .unspecified
         }
      }
    }
}

