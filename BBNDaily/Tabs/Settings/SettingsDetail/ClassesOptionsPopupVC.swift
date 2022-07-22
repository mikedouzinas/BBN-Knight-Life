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
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        ClassesOptionsPopupVC.newClass = ClassModel(Subject: "", Teacher: "", Room: "", Block: ClassesOptionsPopupVC.newClass.Block)
        DaySelectVC.isEditing = false
        ClassNameVC.link = self
        TeacherNameVC.link = self
        RoomNumVC.link = self
        DaySelectVC.link = self
        self.performSegue(withIdentifier: "textfield", sender: nil)
    }
    static var indexPath = IndexPath(row: 0, section: 0)
    public func editCell(viewModel: ClassModel, indexPath: IndexPath) {
        ClassesOptionsPopupVC.editedClass = viewModel
        ClassesOptionsPopupVC.newClass = viewModel
        DaySelectVC.isEditing = true
        ClassesOptionsPopupVC.indexPath = indexPath
        
        ClassNameVC.link = self
        TeacherNameVC.link = self
        RoomNumVC.link = self
        DaySelectVC.link = self
        self.performSegue(withIdentifier: "textfield", sender: nil)
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
        let oldDoc = memberDocs.document(doc)
        oldDoc.getDocument(completion: { (document, error) in
            if let document = document, document.exists {
                var array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                var i = 0
                for x in array {
                    if (x["name"] ?? "").lowercased().contains("\(LoginVC.fullName.lowercased())") {
                        array.remove(at: i)
                        i-=1
                    }
                    i+=1
                }
                oldDoc.setData(["members":array], merge: true)
            } else {
                print("Document does not exist, no need to remove it! document \(doc)")
            }
            LoginVC.blocks["\(ClassesOptionsPopupVC.currentBlock)"] = realDef
            guard let uid: String = (LoginVC.blocks["uid"] as? String), uid != "" else {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.showFailed("Please Sign Out To Fix Your Account")
                return
            }
            let currDoc = db.collection("users").document("\(uid)")
            currDoc.setData(LoginVC.blocks)
            let memberDoc = memberDocs.document("\(realDef)")
            memberDoc.getDocument(completion: { (document, error) in
                if let document = document, document.exists {
                    var array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                    var i = 0
                    for x in array {
                        if x["name"] == "\(LoginVC.fullName)" {
                            array.remove(at: i)
                            i-=1
                        }
                        i+=1
                    }
                    array.append(["name":"\(LoginVC.fullName)","email":"\(LoginVC.email)", "uid":"\((LoginVC.blocks["uid"] ?? "N/A") as! String)"])
                    
                    LoginVC.classMeetingDays["\(ClassesOptionsPopupVC.currentBlock.lowercased())"] = [((document.data()?["monday"] as? Bool) ?? true), ((document.data()?["tuesday"] as? Bool) ?? true), ((document.data()?["wednesday"] as? Bool) ?? true), ((document.data()?["thursday"] as? Bool) ?? true), ((document.data()?["friday"] as? Bool) ?? true)]
                    memberDoc.setData(["members":array], merge: true)
                    if (((LoginVC.blocks["notifs"] ?? "") as? String) ?? "") == "true" {
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        self.setNotifications()
                    }
                    self.navigationController?.popViewController(animated: true)
                } else {
                    print("Document does not exist, no need to remove it!")
                }
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
                ProgressHUD.showFailed("Failed to find 'special-schedules'")
            } else {
                Classes = [ClassModel]()
                for document in (snapshot?.documents)! {
                    print("docs")
                    let fullName = document.data()["name"] as? String ?? ""
                    let array = fullName.getValues()
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
