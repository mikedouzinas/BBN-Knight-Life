//
//  ClassPopupVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import Firebase
import SkeletonView
import ProgressHUD

class ClassPopupVC: UIViewController, UITableViewDelegate, SkeletonTableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    func collectionSkeletonView(_ skeletonView: UITableView, cellIdentifierForRowAt indexPath: IndexPath) -> ReusableCellIdentifier {
        return blockTableViewCell.identifier
    }
    static var block = ""
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: blockTableViewCell.identifier, for: indexPath) as? blockTableViewCell else {
            fatalError()
        }
        cell.configure(with: members[indexPath.row])
        return cell
    }
    @IBOutlet weak var classAdminLabel: UILabel!
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Members"
    }
    private var members = [Person]()
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton.isHidden = true
        setMembers()
        configureTableView()
    }
    override func viewWillAppear(_ animated: Bool) {
        self.revealViewController()?.gestureEnabled = false
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let person = members[indexPath.row]
        if person.uid != "N/A" && person.uid != "" {
            let db = Firestore.firestore()
            let user = db.collection("users").document("\(person.uid)")
            user.getDocument(completion: { [self] (document, error) in
                if let document = document, document.exists {
                    if (document.data()?["publicClasses"] as? String ?? "false") == "true" {
                        let popup = PersonPopupVC()
                        var a = (document.data()?["A"] as? String ?? "A Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var b = (document.data()?["B"] as? String ?? "B Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var c = (document.data()?["C"] as? String ?? "C Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var d = (document.data()?["D"] as? String ?? "D Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var e = (document.data()?["E"] as? String ?? "E Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var f = (document.data()?["F"] as? String ?? "F Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        var g = (document.data()?["G"] as? String ?? "G Block--").replacingOccurrences(of: "~", with: " ").replacingOccurrences(of: "  ", with: " ")
                        if a.isEmpty {
                            a = "--"
                        }
                        if b.isEmpty {
                            b = "--"
                        }
                        if c.isEmpty {
                            c = "--"
                        }
                        if d.isEmpty {
                            d = "--"
                        }
                        if e.isEmpty {
                            e = "--"
                        }
                        if f.isEmpty {
                            f = "--"
                        }
                        if g.isEmpty {
                            g = "--"
                        }
                        let text = "A: \(a.prefix(a.count-2))\nB: \(b.prefix(b.count-2))\nC: \(c.prefix(c.count-2))\nD: \(d.prefix(d.count-2))\nE: \(e.prefix(e.count-2))\nF: \(f.prefix(f.count-2))\nG: \(g.prefix(g.count-2))"
                        popup.textView.text = text
                        popup.navigationItem.title = "\(person.name.trimmingCharacters(in: .whitespacesAndNewlines))'s Classes"
                        show(popup, sender: nil)
                    }
                    else {
                        ProgressHUD.colorAnimation = .red
                        ProgressHUD.failed("This user has public classes turned off")
                    }
                } else {
                    print("Document does not exist!")
                }
            })
        }
        else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("This user has not set up this shared class")
        }
    }
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet public var HeightConstraint: NSLayoutConstraint!
    func setMembers() {
        let db = Firestore.firestore()
        let memberDocs = db.collection("classes")
        let blockName = (LoginVC.blocks["\(ClassPopupVC.block)"] as? String) ?? "N/A"
        let arr = blockName.getValues()
        self.navigationItem.title = "\(arr[0]) \(arr[1].replacingOccurrences(of: "N/A", with: "")) - \(ClassPopupVC.block)"
        let doc = memberDocs.document(blockName)
        doc.getDocument(completion: { [self] (document, error) in
            members = [Person]()
            if let document = document, document.exists {
                let array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                let creator = (document.data()?["owner"] as? String) ?? "N/A"
                
                let homeworkText = (document.data()?["homework"] as? String) ?? ""
                TextView.text = homeworkText
                if creator != "N/A" {
                    classAdminLabel.text = "Class Admin: \(creator)"
                }
                else {
                    classAdminLabel.text = "Default Class"
                }
                for x in array {
                    members.append(Person(name: (x["name"] ?? ""), email: (x["email"] ?? ""), uid: x["uid"] ?? "N/A"))
                }
                editButton.isHidden = false
            } else {
                print("Document does not exist, no members to add!")
                ProgressHUD.colorAnimation = .red
                ProgressHUD.failed("This class no longer exists! Please change your class in settings.")
            }
            TextView.stopSkeletonAnimation()
            classAdminLabel.stopSkeletonAnimation()
            tableView.stopSkeletonAnimation()
            view.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(0.25))
            tableView.reloadData()
        })
    }
    @IBOutlet public var TextView: UITextView!
    func configureTableView() {
        HeightConstraint.constant = view.frame.height/4
        view.layoutIfNeeded()
        tableView.register(blockTableViewCell.self, forCellReuseIdentifier: blockTableViewCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isSkeletonable = true
        tableView.showAnimatedGradientSkeleton()
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = 50
        
        TextView.isSkeletonable = true
        TextView.showAnimatedGradientSkeleton()
        TextView.skeletonCornerRadius = 4
        
        classAdminLabel.isSkeletonable = true
        classAdminLabel.showAnimatedGradientSkeleton()
        classAdminLabel.skeletonCornerRadius = 4
    }
    @IBAction func editText(_ sender: UIButton) {
        TextEditVC.link = self
        self.performSegue(withIdentifier: "edit", sender: nil)
    }
}

