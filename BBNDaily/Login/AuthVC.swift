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

// Parent class that is never shown, but only overridden
class AuthVC: CustomLoader {
    static var isFirstTime = true
    func signOutToken() {
        do {
            self.showLoader(text: "Signing you out...")
            try FirebaseAuth.Auth.auth().signOut()
            LoginVC.blocks = ["A":"","B":"","C":"","D":"","E":"","F":"","G":"","grade":"","l-monday":"2nd Lunch","l-tuesday":"2nd Lunch","l-wednesday":"2nd Lunch","l-thursday":"2nd Lunch","l-friday":"2nd Lunch","l-a":"","l-b":"","l-c":"","l-d":"","l-e":"","l-f":"","l-g":"","googlePhoto":"false","lockerNum":"","notifs":"true","room-advisory":"","uid":""]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            hideLoader(completion: {
                ProgressHUD.colorAnimation = .green
                ProgressHUD.succeed("Successfully signed out")
                if let settingsSelf = (self as? SettingsVC) {
                    settingsSelf.performSegue(withIdentifier: "Reset", sender: nil)
                }
                else {
                    self.performSegue(withIdentifier: "logOut", sender: nil)
                }
            })
        }
        catch {
            ProgressHUD.failed("Failed to Sign Out")
        }
    }
    
    // HQ-649: let a student clear their own A-G classes and start over.
    //
    // A class lives in two places — the student's own `A`-`G` fields, and that class's
    // `members` array in `classes/{key}`. Clearing only the first leaves the student on
    // rosters for classes they can no longer see in-app (ClassPopupVC reads `members` to
    // show who else is in a class), which is how a school of ~600 ended up with 638 user
    // records and 374 class documents carrying stale membership.
    //
    // Blocks are processed one at a time, in order, and a letter in `users/{uid}` is only
    // cleared *after* that class's roster removal succeeds. That ordering is what makes
    // this resumable: if it fails partway, every letter before the failure is fully clean
    // (doc and roster both), every letter at or after it is fully untouched — never a student
    // stuck on a roster for a class their own document no longer lists. Calling it again
    // just continues from where it stopped; re-clearing an already-empty letter, or
    // re-removing an already-absent member, is a no-op either way.
    func resetClasses(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else {
            completion(.failure(NSError(domain: "KnightLife", code: 1, userInfo: [NSLocalizedDescriptionKey: "No signed-in account"])))
            return
        }
        resetNextBlock(letters: ["A", "B", "C", "D", "E", "F", "G"], uid: uid, completion: completion)
    }

    private func resetNextBlock(letters: [String], uid: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        guard let letter = letters.first else {
            completion(.success(()))
            return
        }
        let remaining = Array(letters.dropFirst())
        let advance: () -> Void = { self.resetNextBlock(letters: remaining, uid: uid, completion: completion) }

        // Same guard setLoginInfo() uses elsewhere to recognize a real "Subject~Teacher~Room~Block"
        // assignment versus an empty or malformed field.
        let classKey = (LoginVC.blocks[letter] as? String) ?? ""
        guard classKey.contains("~"), !classKey.contains("/") else {
            // Nothing really assigned here - already clear, nothing to remove from a roster.
            clearLetterLocally(letter: letter, uid: uid) { result in
                switch result {
                case .success: advance()
                case .failure(let error): completion(.failure(error))
                }
            }
            return
        }

        let db = Firestore.firestore()
        let classDoc = db.collection("classes").document(classKey)
        classDoc.getDocument { [self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                // The class doc is already gone - nothing to remove this student from.
                clearLetterLocally(letter: letter, uid: uid) { result in
                    switch result {
                    case .success: advance()
                    case .failure(let error): completion(.failure(error))
                    }
                }
                return
            }
            var members = (snapshot.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
            // Matched on uid, not name - two students can share a name, only one shares a uid.
            members.removeAll { ($0["uid"] ?? "") == uid }
            classDoc.setData(["members": members], merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                clearLetterLocally(letter: letter, uid: uid) { result in
                    switch result {
                    case .success: advance()
                    case .failure(let error): completion(.failure(error))
                    }
                }
            }
        }
    }

    private func clearLetterLocally(letter: String, uid: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData([letter: ""]) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            LoginVC.blocks[letter] = ""
            completion(.success(()))
        }
    }

    // HQ-620: prompt a returning student when their classes were set for an earlier
    // school year than the one that's actually running now.
    //
    // "Which year is it" is deliberately not computed here. `schedules/term` already
    // carries the current year's start/end date, kept current by whoever runs the admin
    // schedule tool, because the rest of the app already depends on it being current
    // (it's how the app decides whether a weekday is inside the school year at all). This
    // reads that same value fresh rather than trusting `LoginVC.term`, which is loaded by
    // a separate, unrelated call in setLoginInfo() with no guaranteed ordering against this.
    //
    // Never blocks getting into the app: called after the student is already in the tab
    // bar, and any read failure here just means no prompt this launch - same as `LoginVC.term`
    // itself, where a failed read leaves the rule not applied rather than the app broken.
    func checkNewYearSetup() {
        // Whether the student HAS classes decides the wording, and nothing else.
        //
        // This used to be `guard hasAnyClass else { return }`, on the reading that a student with
        // no classes has nothing to "roll over" and is really a new user for onboarding to handle.
        // That inverted on 2026-09-03, when every student's A-G was cleared for the new year: all
        // 639 accounts now have no classes, so the guard would have suppressed the prompt for the
        // entire school on the first morning. They would have opened the app to seven empty blocks
        // with nothing telling them the scan exists.
        //
        // A student with no classes needs this prompt MORE than one with last year's, not less.
        let hasAnyClass = ["A", "B", "C", "D", "E", "F", "G"].contains {
            ((LoginVC.blocks[$0] as? String) ?? "").contains("~")
        }

        Firestore.firestore().collection("schedules").document("term").getDocument { snapshot, error in
            guard error == nil, let data = snapshot?.data(),
                  let start = data["start"] as? String else { return }
            let recordedFor = LoginVC.blocks["classesSetForTermStart"] as? String
            guard recordedFor != start else { return } // already set up for the current term

            // WHEN to ask is a school-calendar decision, so it lives in schedules/term with
            // the rest of the school calendar rather than as a constant compiled into the
            // app. An admin moves it; nobody ships a release.
            //
            //   rolloverPromptFrom   "yyyy/M/d", optional. The day the prompt starts
            //                        appearing. Defaults to the term's own start date, so
            //                        with no admin action at all the app asks on the first
            //                        day of school and not before.
            //   rolloverPromptUntil  "yyyy/M/d", optional. The day it stops. Defaults to 30
            //                        days after the window opens, so a student who does not
            //                        open the app in September is not asked in April.
            //
            // Nothing is recorded while the window is still shut, and that is the point.
            // Recording early was the bug: it marked a student as set up for a term that had
            // not begun, so when it did begin recordedFor == start and the prompt never fired.
            guard let window = Self.rolloverWindow(from: data, termStart: start) else { return }
            let today = Calendar.current.startOfDay(for: Date())
            guard today >= window.opens else { return }   // too early: wait, record nothing
            guard today <= window.closes else {           // long past: not a rollover
                Self.recordTermSetup(start)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.presentNewYearPrompt(termStart: start, hasAnyClass: hasAnyClass)
            }
        }
    }

    /// The dates between which the new-year prompt may appear, read from `schedules/term`.
    ///
    /// Returns nil when the term's own start date cannot be parsed, and nil means do nothing.
    /// An unreadable school calendar must never turn into a dialog asking a student to delete
    /// their schedule.
    private static func rolloverWindow(from data: [String: Any], termStart: String) -> (opens: Date, closes: Date)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        let calendar = Calendar.current
        guard let startDate = formatter.date(from: termStart) else { return nil }

        let opens = (data["rolloverPromptFrom"] as? String).flatMap { formatter.date(from: $0) } ?? startDate
        let defaultClose = calendar.date(byAdding: .day, value: 30, to: opens) ?? opens
        let closes = (data["rolloverPromptUntil"] as? String).flatMap { formatter.date(from: $0) } ?? defaultClose
        // A window that closes before it opens is a typo in the calendar, not an instruction.
        guard opens <= closes else { return nil }

        return (calendar.startOfDay(for: opens), calendar.startOfDay(for: closes))
    }
    /// Records the term this student's classes are considered set up for, without prompting.
    private static func recordTermSetup(_ termStart: String) {
        LoginVC.blocks["classesSetForTermStart"] = termStart
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else { return }
        Firestore.firestore().collection("users").document(uid)
            .setData(["classesSetForTermStart": termStart], merge: true)
    }

    private func topPresenter() -> UIViewController? {
        var top = UIApplication.shared.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// - Parameter hasAnyClass: whether anything is currently set, which changes the wording only.
    ///   Offering to "clear last year's classes" to a student who has none reads as a bug, and
    ///   after the 2026-09-03 reset that is every student in the school.
    private func presentNewYearPrompt(termStart: String, hasAnyClass: Bool) {
        guard let presenter = topPresenter() else { return }
        let alert = UIAlertController(
            title: "New School Year",
            message: hasAnyClass
                ? "Looks like a new year started. Want to clear last year's classes and set up your new ones?\n\nIf you have your printed schedule, you can take a photo of it instead of typing seven classes in."
                : "Welcome back. Your classes aren't set for this year yet.\n\nIf you have your printed schedule, you can take a photo of it instead of typing seven classes in.",
            preferredStyle: .alert
        )
        // Scanning is offered first because this is the exact moment it is worth most: the
        // student is being asked to set up seven blocks, and of 639 user records only 220 have
        // any class set - almost everyone else had used the app and set other preferences, then
        // hit the seven-class setup and stopped (HQ-877). Typing is what they stopped at.
        alert.addAction(UIAlertAction(title: "Scan My Schedule", style: .default, handler: { [weak self] _ in
            self?.startNewYearSetup(termStart: termStart, thenScan: true)
        }))
        alert.addAction(UIAlertAction(title: "Set Up by Hand", style: .default, handler: { [weak self] _ in
            self?.startNewYearSetup(termStart: termStart, thenScan: false)
        }))
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func startNewYearSetup(termStart: String, thenScan: Bool) {
        guard let presenter = topPresenter() else { return }
        presenter.showLoader(text: "Clearing last year's classes...")
        resetClasses { [weak self] result in
            guard let self = self else { return }
            self.topPresenter()?.hideLoader(completion: {
                switch result {
                case .success:
                    // Recorded only on success, so a reset that fails partway (already left
                    // in a consistent state by resetClasses' own per-block ordering) gets
                    // asked again next launch rather than silently marked done.
                    // One writer for this field, so the prompted path and the silent path
                    // cannot disagree about how it is stored. setData(merge:) inside, because
                    // updateData fails outright on a record that does not exist yet.
                    Self.recordTermSetup(termStart)
                    if thenScan {
                        self.presentScheduleScan()
                    } else {
                        ProgressHUD.colorAnimation = .green
                        ProgressHUD.succeed("Classes cleared - head to Settings to set your new ones")
                    }
                case .failure:
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Didn't finish - you can also clear classes any time from Settings")
                }
            })
        }
    }

    /// Opens the scanner from the new-year prompt.
    ///
    /// Modally, inside its own navigation controller, because there is no guarantee of one to
    /// push onto here - this fires from a launch-time prompt over whatever screen happens to be
    /// showing, not from Settings. ScheduleScanVC closes itself with `closeSelf()`, which pops
    /// when it was pushed and dismisses when it is a modal root, so both entry points work.
    private func presentScheduleScan() {
        guard let presenter = topPresenter() else { return }
        let scan = ScheduleScanVC()
        let nav = UINavigationController(rootViewController: scan)
        scan.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Later", style: .plain, target: scan, action: #selector(ScheduleScanVC.closeSelf))
        nav.modalPresentationStyle = .fullScreen
        presenter.present(nav, animated: true)
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
    func updateSpecialSchedules(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        // Every read here is independent, so they run together and the completion waits on all
        // of them. Before this the callback was attached to whichever read happened to be
        // written last, which meant a caller could be told the schedule was ready while
        // `specialDays`, `breaks` or `term` were still nil.
        let group = DispatchGroup()

        group.enter()
        db.collection("schedules").document("special").getDocument(completion: {(snapshot, error) in
            defer { group.leave() }
            if error != nil {
                ProgressHUD.failed("Failed to find 'special'")
            } else {
                var tempDict = [String: Day]()
                
                if let days = snapshot?.data() {
                    for (key, value) in days {
                        // HQ-627. This loop reads EVERY field of `schedules/special`, and every
                        // cast in it used to be forced. One stray top-level field, one day
                        // missing `type`, one noschool day missing `reason`, and the app died on
                        // launch for all 582 students with no message saying why.
                        //
                        // The publish path already refuses to write a document-level field (see
                        // the comment at the top of web/src/lib/schedule/publish.ts), so this is
                        // about the ninety days that predate that tool, and about the next person
                        // to edit one in the console.
                        //
                        // A malformed day is skipped. That day falls through to the regular
                        // schedule, which is wrong for one date; a crash is wrong for everybody.
                        guard let data = value as? [String: Any],
                              let type = data["type"] as? String else { continue }
                        var day = Day(type: type)

                        if day.type == "noschool" {
                            day.reason = (data["reason"] as? String) ?? "No Class"
                        } else if day.type == "blocks" {
                            day.blocks = [Event]()
                            let schedule = data["blocks"] as? [[String: Any]] ?? [[String: Any]]()
                            for scheduleBlock in schedule {
                                if let event = self.convertToEvent(scheduleBlock: scheduleBlock) {
                                    day.blocks?.append(event)
                                }
                            }
                        } else if day.type == "image" {
                            // An image day with no url has nothing to show, so it is not a day.
                            guard let imageUrl = data["imageUrl"] as? String else { continue }
                            day.imageUrl = imageUrl
                        }
                        tempDict[key] = day
                    }
                }
                LoginVC.specialDays = tempDict
            }
        })
        group.enter()
        db.collection("schedules").document("break").getDocument(completion: {(snapshot, error) in
            defer { group.leave() }
            if error != nil {
                ProgressHUD.failed("Failed to find 'break'")
            } else {
                var tempArr = [Break]()
                
                if let breaks = snapshot?.data() {
                    for (key, value) in breaks {
                        // Every cast here used to be forced, and each one was a launch crash
                        // waiting on a typo in a Firestore document: a value that is not a map,
                        // a missing `reason`, or a key with no "-" (which made `dates[1]` an
                        // index out of range). One person editing the console by hand could take
                        // the app down for everyone, and nothing in the app would say why.
                        //
                        // A malformed break is now skipped. One break silently missing is a wrong
                        // schedule for one span; a crash is no app at all.
                        guard let data = value as? [String: Any],
                              let reason = data["reason"] as? String else { continue }
                        let dates = key.components(separatedBy: "-")
                        guard dates.count == 2 else { continue }
                        tempArr.append(Break(reason: reason, startDate: dates[0], endDate: dates[1]))
                    }
                }
                LoginVC.breaks = tempArr
            }
        })
        // The school year's boundaries. resolveDay treats a weekday outside them as no school
        // instead of falling through to the weekly pattern, which is what showed students a
        // seven-block Wednesday in the middle of August.
        //
        // Left nil on any failure, and nil means "do not apply the rule". A read that fails
        // must never render as "there is no school today" for the whole school, so every exit
        // below leaves the app behaving exactly as it did before this document existed.
        group.enter()
        db.collection("schedules").document("term").getDocument(completion: {(snapshot, error) in
            defer { group.leave() }
            guard error == nil,
                  let data = snapshot?.data(),
                  let start = data["start"] as? String,
                  let end = data["end"] as? String else {
                LoginVC.term = nil
                return
            }
            LoginVC.term = Term(startDate: start,
                                endDate: end,
                                reason: (data["reason"] as? String) ?? "Summer break")
        })
        // The three reads above are the whole launch path now, and the completion fires when
        // ALL of them have finished rather than when whichever one happened to be last does.
        // It used to be tied to the `special-schedules` scan, which meant the callback could
        // run before `specialDays`, `breaks` or `term` had arrived, and worked only because
        // that scan was the slowest.
        group.notify(queue: .main) {
            completion(.success(()))
        }
    }
    func setProfileImage(useGoogle: Bool, width: UInt, completion: @escaping (Swift.Result<UIImageView, Error>) -> Void) {
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
            GIDSignIn.sharedInstance.restorePreviousSignIn { [self] user, error in
                if error != nil || user == nil {
                    // Show the app's signed-out state.
                    let imgUrl = (Auth.auth().currentUser?.photoURL!)!
                    setImage(url: imgUrl, completion: { result in
                        switch result {
                        case .success(_):
                            completion(.success(LoginVC.profilePhoto))
                        case .failure(_):
                            print("error")
                        }
                    })
                } else {
                    // Show the app's signed-in state.
                    print("GOT IMAGE")
                    
                    let newurl = (user!.profile?.imageURL(withDimension: width)!)!
                    setImage(url: newurl, completion: { result in
                        switch result {
                        case .success(_):
                            completion(.success(LoginVC.profilePhoto))
                        case .failure(_):
                            print("error")
                        }
                    })
                }
            }
        }
    }
    func setImage(url: URL, completion: @escaping (Swift.Result<UIImage?, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
            else {
                LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
                completion(.success(LoginVC.profilePhoto.image))
                return
            }
            DispatchQueue.main.async() {
                LoginVC.profilePhoto.image = image
                completion(.success(LoginVC.profilePhoto.image))
            }
        }.resume()
    }
    func setLoginInfo() {
        LoginVC.fullName = (FirebaseAuth.Auth.auth().currentUser?.displayName ?? "").replacingOccurrences(of: "**", with: "")
        LoginVC.email = FirebaseAuth.Auth.auth().currentUser?.email ?? ""
        LoginVC.phoneNum = FirebaseAuth.Auth.auth().currentUser?.phoneNumber ?? ""
        let db = Firestore.firestore()
        refreshAdminStatus(db: db)
        refreshLunchMenuWeeks(db: db)
        db.collection("ifstatements").document("ifstatements").getDocument(completion: {(snapshot, error) in
            if error != nil {
                ProgressHUD.failed("Failed to find 'ifstatements'")
                print("failed to find \(error)")
            } else {
                if ((snapshot?.data()?["shouldUseOnlineClasses"] as? Bool) ?? false) {
                    db.collection("schedules").document("regular").getDocument(completion: {(snap, err) in
                        if (err != nil) {
                            ProgressHUD.failed("Failed to find regular schedules")
                        } else {
                            for day in ["monday", "tuesday", "wednesday", "thursday", "friday"] {
                                let schedule = snap?.data()?[day] as? [[String: Any]] ?? [[String: Any]]()
                                var blocks = [Event]()
                                for scheduleBlock in schedule {
                                    if let event = self.convertToEvent(scheduleBlock: scheduleBlock) {
                                        blocks.append(event)
                                    }
                                }
                                // Only overwrite the built-in weekly pattern when Firestore
                                // actually supplied one. An empty array here would replace a
                                // working default with a blank day, so one malformed document
                                // would empty the schedule for every student rather than break
                                // the single block it actually describes.
                                if !blocks.isEmpty {
                                    regularSchedule[day] = blocks
                                }
                            }
                        }
                    })
                }
                else {
                    print("false!")
                }
                if let busNumber = snapshot?.data()?["busNumber"] as? Int, busNumber != 0 {
                    LoginVC.busNumber = busNumber
                }
            }
        })
        updateSpecialSchedules(completion: {_ in
            
        })
        // change here to filter for the users id
        db.collection("users").document("\(FirebaseAuth.Auth.auth().currentUser?.uid ?? "--")").getDocument { (document, error) in
            if error != nil {
                ProgressHUD.failed("Failed to find 'users'")
            } else {
                //                var isCreated = false
                if !(document?.exists ?? false) {
                    guard let Login = (self as? LoginVC) else {
                        //                        print("not LoginVC")
                        self.hideLoader(completion: {
                            self.hideLoaderView()
                            self.performSegue(withIdentifier: "SignedIn", sender: nil)
                        })
                        return
                    }
                    self.setNotifications()
                    let db = Firestore.firestore()
                    let currDoc = db.collection("users").document("\(Auth.auth().currentUser?.uid ?? "")")
                    LoginVC.blocks["uid"] = Auth.auth().currentUser?.uid ?? ""
                    ProgressHUD.colorAnimation = .green
                    ProgressHUD.succeed("Welcome to Knight Life!")
                    currDoc.setData(LoginVC.blocks)
                    self.hideLoader(completion: {
                        self.hideLoaderView()
                        Login.callTabBar()
                    })
                }
                //                            isCreated = true
                LoginVC.blocks = document?.data() ?? [String: Any]()
                ScheduleNotifications.syncSubscription()
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
                // `LoginVC.blocks` is a Firestore user document, so a non-string here is a
                // launch crash rather than a missing profile picture.
                if (LoginVC.blocks["googlePhoto"] as? String) == "true" {
                    self.setProfileImage(useGoogle: true, width: UInt(self.view.frame.width), completion: {_ in
                        
                    })
                }
                else {
                    self.setProfileImage(useGoogle: false, width: UInt(self.view.frame.width), completion: {_ in
                    })
                }
                myGroup.notify(queue: .main) {
                    print("Finished all requests.")
                    self.hideLoader(completion: {
                        self.hideLoaderView()
                        guard let Login = (self as? LoginVC) else {
                            //                                        print("not LoginVC")
                            self.performSegue(withIdentifier: "SignedIn", sender: nil)
                            self.checkNewYearSetup()
                            return
                        }
                        Login.callTabBar()
                        self.checkNewYearSetup()
                    })
                }
                return
            }
            self.hideLoader(completion: {
                self.hideLoaderView()
                guard let Login = (self as? LoginVC) else {
                    //                        print("not LoginVC")
                    self.performSegue(withIdentifier: "SignedIn", sender: nil)
                    return
                }
                Login.callTabBar()
            })
        }
    }
    
    // Look up whether this account may publish schedules.
    //
    // The list lives in the admins collection in Firestore, keyed by lowercase email, which is
    // the same source the security rules read. Before this, Settings.swift substring-matched
    // three hardcoded addresses that all belonged to people who had left, so the maintainers
    // taking the project over had write permission and no way to reach the editor.
    //
    // Any failure means not an admin. The editor is hidden, the rules still enforce the truth,
    // and nothing else in the app depends on this.
    func refreshAdminStatus(db: Firestore) {
        let email = LoginVC.email.lowercased()
        guard !email.isEmpty else {
            LoginVC.isAdmin = false
            return
        }
        db.collection("admins").document(email).getDocument { (snapshot, error) in
            LoginVC.isAdmin = (error == nil) && (snapshot?.exists ?? false)
        }
    }

    /// Record which weeks have a lunch menu, so the schedule only offers "Press for menu"
    /// when pressing it will actually show something. Keys are the "M/d" of that week's Monday.
    /// A blank or unparseable value counts as no menu, which is exactly what LunchMenuVC does
    /// with it.
    func refreshLunchMenuWeeks(db: Firestore) {
        db.collection("schedules").document("menus").getDocument { (snapshot, error) in
            guard error == nil, let data = snapshot?.data() else { return }
            var weeks = Set<String>()
            for (week, value) in data {
                guard let urlString = value as? String,
                      !urlString.trimmingCharacters(in: .whitespaces).isEmpty,
                      URL(string: urlString) != nil else { continue }
                weeks.insert(week)
            }
            LoginVC.lunchMenuWeeks = weeks
        }
    }

    /// One block from Firestore, or nil when the document does not describe a usable one.
    ///
    /// Every cast here used to be forced, including `scheduleBlock["type"]! as! String`, so a
    /// block missing a field was a launch crash for every student rather than one bad row.
    /// The published data is validated by the admin tool, but roughly ninety days were
    /// hand-entered in the Firestore console before that tool existed, and nothing stops
    /// somebody editing one by hand tomorrow.
    ///
    /// Returning nil rather than a partial Event on purpose: a block with no start time is
    /// not a block, and silently keeping it would put an untimed row in a student's day where
    /// a real class should be. Dropping it leaves a visible gap, which is a failure a person
    /// can notice and report.
    func convertToEvent(scheduleBlock: [String: Any]) -> Event? {
        guard let type = scheduleBlock["type"] as? String else { return nil }
        var ev = Event(type: type)

        if ev.type == "block" {
            guard let block = scheduleBlock["block"] as? String,
                  let name = scheduleBlock["name"] as? String,
                  let startTime = scheduleBlock["startTime"] as? String,
                  let endTime = scheduleBlock["endTime"] as? String else { return nil }
            ev.block = block
            ev.name = name
            ev.startTime = startTime
            ev.endTime = endTime
        } else if ev.type == "lunch" {
            guard let startTime = scheduleBlock["startTime"] as? String,
                  let endTime = scheduleBlock["endTime"] as? String else { return nil }
            ev.startTime = startTime
            ev.endTime = endTime
        } else if ev.type == "specific" {
            ev.filter = (scheduleBlock["filter"] as? [String])
            ev.matchMode = (scheduleBlock["matchMode"] as? String)
            ev.lunchBlock = (scheduleBlock["lunchBlock"] as? String)
            ev.contents = [Event]()
            // `as?` rather than `as!`: a `specific` block with no contents is empty, not fatal.
            for subBlock in (scheduleBlock["contents"] as? [[String: Any]] ?? []) {
                if let sub = convertToEvent(scheduleBlock: subBlock) {
                    ev.contents?.append(sub)
                }
            }
        }

        return ev
    }
}


