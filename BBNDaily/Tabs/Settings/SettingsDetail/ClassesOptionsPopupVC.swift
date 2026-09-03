//
//  ClassesOptionsVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import SkeletonView
import ProgressHUD
import Firebase

class ClassesOptionsPopupVC: UIViewController, UISearchBarDelegate, UITableViewDelegate, SkeletonTableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredClasses.count
    }
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return editClassTableViewCell.identifier
    }
    var classIsEditing = false
    // HQ-658: adding a class is one screen now (AddClassVC), not the four-screen
    // Name -> Teacher -> Room -> DaySelect chain. Editing an existing class still goes
    // through that chain via editCell(viewModel:indexPath:) below - unchanged, since its
    // rename-migration logic is already correct and out of this ticket's scoped-down
    // version.
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        ClassesOptionsPopupVC.newClass = ClassModel(Subject: "", Teacher: "", Room: "", Block: ClassesOptionsPopupVC.newClass.Block)
        classIsEditing = false
        let vc = AddClassVC()
        vc.link = self
        navigationController?.pushViewController(vc, animated: true)
    }
    func presentTextfield() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TextfieldNav") as? UINavigationController
        let vc2 = vc?.children[0] as? ClassNameVC
        vc2?.link = self
        
        guard let vc = vc else {
            return
        }
        present(vc, animated: true)
    }
    static var indexPath = IndexPath(row: 0, section: 0)
    public func editCell(viewModel: ClassModel, indexPath: IndexPath) {
        classIsEditing = true
        ClassesOptionsPopupVC.editedClass = viewModel
        ClassesOptionsPopupVC.newClass = viewModel
        ClassesOptionsPopupVC.indexPath = indexPath
        
        presentTextfield()
    }
    static var newClass = ClassModel(Subject: "TOADS", Teacher: "MR MIKE", Room: "300", Block: "G")
    static var editedClass = ClassModel(Subject: "TOADS", Teacher: "MR MIKE", Room: "300", Block: "G")
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: editClassTableViewCell.identifier, for: indexPath) as? editClassTableViewCell else {
            fatalError()
        }
        cell.link = self
        cell.configure(with: filteredClasses[indexPath.row], indexPath: indexPath)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let db = Firestore.firestore()
        let selectedRow = filteredClasses[indexPath.row]
        let realDef = "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)".replacingOccurrences(of: "N/A", with: "")
        let memberDocs = db.collection("classes")
        var doc = (LoginVC.blocks["\(ClassesOptionsPopupVC.currentBlock)"] as? String) ?? "N/A"
        if doc == "" {
            doc = "OLD"
        }
        // Checked BEFORE anything is written, not between the two writes.
        //
        // This guard used to sit after the old roster had already been rewritten, so an account
        // with no uid was taken off its previous class, told to sign out, and left in neither
        // class. The uid is also what both roster edits below match on, so there is nothing
        // correct either of them can do without it.
        guard let uid: String = (LoginVC.blocks["uid"] as? String), uid != "" else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("Please Sign Out To Fix Your Account")
            return
        }

        let oldDoc = memberDocs.document(doc)
        oldDoc.getDocument(completion: { (document, error) in
            if let document = document, document.exists {
                var array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                let before = array.count
                // By uid, and by EQUALITY.
                //
                // This matched on whether a member's name CONTAINED the caller's name, lowercased.
                // Any student whose name is a substring of another's ("Ana" in "Ana Maria", "Kim"
                // in "Kimberly") took that person off the roster on their way out of a class, and
                // nothing anywhere would have shown it.
                //
                // It is also what HQ-911's rules require: `removesOnlySelf()` accepts a roster
                // that shrank by exactly one entry, and that entry being the caller. Removing two
                // people is refused outright, so the old code's wide match could also fail the
                // write and leave the student on a class they had left.
                array.removeAll { ($0["uid"] ?? "") == uid }
                if array.count != before {
                    oldDoc.setData(["members": array], merge: true) { error in
                        if let error = error {
                            // Not surfaced: the student is about to be joined to the new class,
                            // which is what they asked for. Being left on an old roster is the
                            // lesser wrong and telling them the tap failed would be false.
                            print("leaving \(doc) failed: \(error)")
                        }
                    }
                }
            } else {
                print("Document does not exist, no need to remove it! document \(doc)")
            }
            LoginVC.updateField("\(ClassesOptionsPopupVC.currentBlock)", to: realDef)
            let memberDoc = memberDocs.document("\(realDef)")
            memberDoc.getDocument(completion: { (document, error) in
                // A missing document is NOT a reason to stop.
                //
                // This used to be `if document.exists { ...join, pop... } else { print(...) }`, so
                // when the key reconstructed from the row did not name a real document - which is
                // what happens whenever a stored key holds a variant spelling, since `realDef` is
                // rebuilt from the parsed fields rather than read back - the student tapped their
                // class and the screen did nothing at all. No error, no dismissal, no membership.
                // The only recoverable move was backing out and guessing.
                //
                // The student's intent is the same either way: put me in this class. `setData`
                // with `merge: true` creates the document if it is not there, which is what the
                // scan path already does.
                let data = document?.data()
                var array = (data?["members"] as? [[String: String]]) ?? [[String: String]]()

                // Append only if absent, matched by UID, and never reordered.
                //
                // Two reasons, and the second one is now load-bearing:
                //
                // 1. Matched by uid, not by name. This used to remove every entry whose name
                //    equalled the caller's, and the removal above it still matches on a name
                //    SUBSTRING - so two students whose names contain one another take each other
                //    off rosters. A uid is the only identifier here that is actually unique.
                //
                // 2. Never reordered. HQ-911 narrowed `classes` update to: the roster is
                //    unchanged, or it differs by exactly one entry and that entry is the caller.
                //    The old remove-then-append produced an array of the SAME SIZE in a DIFFERENT
                //    ORDER whenever the student was already a member, and Firestore compares
                //    lists by order - so `rosterUnchanged()` was false, `addsOnlySelf()` needed
                //    size + 1, and the write was refused. It had no completion handler, so the
                //    refusal was silent and the screen popped as though it had worked.
                if !array.contains(where: { ($0["uid"] ?? "") == uid }) {
                    array.append(["name": LoginVC.fullName, "email": LoginVC.email, "uid": uid])
                }

                LoginVC.classMeetingDays["\(ClassesOptionsPopupVC.currentBlock.lowercased())"] = [((data?["monday"] as? Bool) ?? true), ((data?["tuesday"] as? Bool) ?? true), ((data?["wednesday"] as? Bool) ?? true), ((data?["thursday"] as? Bool) ?? true), ((data?["friday"] as? Bool) ?? true)]

                // `name` and `block` so a document created here is the same shape as one created
                // by AddClassVC or by a scan. A members-only document has no name, and the picker
                // renders a nameless document as "N/A".
                var payload: [String: Any] = ["members": array, "name": realDef, "block": ClassesOptionsPopupVC.currentBlock.uppercased()]
                if document?.exists != true { payload["owner"] = LoginVC.email }

                memberDoc.setData(payload, merge: true, completion: { error in
                    if let error = error {
                        ProgressHUD.colorAnimation = .red
                        ProgressHUD.failed("Couldn't join that class. Try again.")
                        print("join class failed for \(realDef): \(error)")
                        return
                    }
                    if (((LoginVC.blocks["notifs"] ?? "") as? String) ?? "") == "true" {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        self.setNotifications()
                    }
                    self.navigationController?.popViewController(animated: true)
                })
            })
        })
       
    }
    static var currentBlock = "G"
    public var Classes = [ClassModel]()
    public var filteredClasses = [ClassModel]()
    private let SearchController = UISearchController(searchResultsController: nil)
    override func viewDidLoad() {
        super.viewDidLoad()
        configureClasses()
        createSearchBar()
        configureTableView()
    }
    func configureClasses() {
        let db = Firestore.firestore()
        db.collection("classes").whereField("block", isEqualTo: "\(ClassesOptionsPopupVC.currentBlock.uppercased())").getDocuments { [self] (snapshot, error) in
            if error != nil {
                ProgressHUD.failed("Failed to find 'special-schedules'")
            } else {
                Classes = [ClassModel]()
                // One row per DISTINCT class, keyed canonically.
                //
                // Two documents can describe the same class: `Free~~~G` and `Free~N/A~N/A~G`, or
                // "Ms. Rose" and "Ms. ROSE". Listing both puts two identical-looking rows in the
                // picker, which is what Mike saw in G block - and picking either one is a guess
                // about which roster the rest of the school is on.
                var seen = Set<String>()
                for document in (snapshot?.documents)! {
                    // The document ID *is* the class key, so it is the right fallback when `name`
                    // is missing. It is missing on every class an earlier version of the scan
                    // created, and without this those render from "" as "N/A / N/A / N/A" - the
                    // class the student just saved, unrecognisable in their own picker. Reading the
                    // ID fixes those in place, with no migration and no rescan.
                    let fullName = (document.data()["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        ?? document.documentID
                    let array = fullName.getValues()

                    let canonical = ClassIdentity.canonicalClassKey(
                        subject: array[0].blankIfNotAvailable(),
                        teacher: array[1].blankIfNotAvailable(),
                        room: array[2].blankIfNotAvailable(),
                        block: array[3].isEmpty ? ClassesOptionsPopupVC.currentBlock : array[3])
                    guard seen.insert(canonical).inserted else { continue }

                    Classes.append(ClassModel(Subject: array[0], Teacher: array[1], Room: array[2], Block: array[3]))
                }
                tableView.stopSkeletonAnimation()
                view.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(0.25))
                filteredClasses = Classes
                tableView.reloadData()
            }
        }
        ClassesOptionsPopupVC.newClass.Block = "\(ClassesOptionsPopupVC.currentBlock)"
    }
    func configureTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.register(editClassTableViewCell.self, forCellReuseIdentifier: editClassTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 50
        tableView.estimatedRowHeight = 50
        tableView.isSkeletonable = true
        tableView.showAnimatedGradientSkeleton()
    }
   
    public var tableView = UITableView()
    func createSearchBar() {
        self.navigationItem.searchController = SearchController
        self.SearchController.searchBar.delegate = self
        self.navigationItem.hidesSearchBarWhenScrolling = false
        SearchController.hidesNavigationBarDuringPresentation = false
        SearchController.searchBar.searchTextField.layer.cornerRadius = 8
        SearchController.searchBar.searchTextField.layer.masksToBounds = true
        SearchController.searchBar.tintColor = .systemBlue
        SearchController.obscuresBackgroundDuringPresentation = false
        self.navigationItem.title = "Available Classes in \(ClassesOptionsPopupVC.currentBlock)"
        SearchController.searchBar.placeholder = "Search existing classes or add a new one"
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let lowercased = searchText.lowercased()
        if searchText == "" {
            filteredClasses = Classes
            tableView.reloadData()
            return
        }
        filteredClasses = Classes.filter({
            $0.Teacher.lowercased().contains(lowercased) || $0.Subject.lowercased().contains(lowercased) || $0.Block.lowercased().contains(lowercased) || $0.Room.lowercased().contains(lowercased)
        })
        tableView.reloadData()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredClasses = Classes
        tableView.reloadData()
    }
}
