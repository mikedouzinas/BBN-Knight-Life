//
//  detailedWorkVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import Firebase

class detailedWorkVC: UIViewController {
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var detailedTextView: UITextView!
    static var link: WorkVC!
    @IBAction func removeTask(_ sender: Any) {
        let refreshAlert = UIAlertController(title: "Delete Task", message: "Are you sure? This action cannot be undone.", preferredStyle: .alert)
        refreshAlert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { (action: UIAlertAction!) in
            let tempTasks = LoginVC.blocks["tasks"] as? [[String: Any]]
            let index = detailedWorkVC.link.selectedTask.index
            if var tempTasks = tempTasks {
                tempTasks.remove(at: index)
                LoginVC.blocks["tasks"] = tempTasks
                let db = Firestore.firestore()
                let currDoc = db.collection("users").document((LoginVC.blocks["uid"] as? String) ?? "")
                currDoc.setData(["tasks": tempTasks], merge: true)
                detailedWorkVC.link.sortTasks()
                detailedWorkVC.link.tableView.reloadData()
                self.navigationController?.popViewController(animated: true)
            }
        }))
        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))
        present(refreshAlert, animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
//        print("\(detailedWorkVC.link.selectedTask.dueDate)")
        dateLabel.text = "Due \(detailedWorkVC.link.selectedTask.dueDate.stringDateFromMultipleFormats(preferredFormat: 7) ?? "")"

        detailedTextView.text = "\(detailedWorkVC.link.selectedTask.description)"
        self.title = "\(detailedWorkVC.link.selectedTask.title)"
    }
}
