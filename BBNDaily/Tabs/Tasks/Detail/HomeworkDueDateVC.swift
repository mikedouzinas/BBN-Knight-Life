//
//  HomeworkDueDateVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import Firebase
import UIKit

class HomeworkDueDateVC: TextFieldVC {
    @IBOutlet weak var datePicker: UIDatePicker!
    static var link: WorkVC!
    @IBAction func pressed(_ sender: Any) {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yyyy"
        let text = dateformatter.string(from: datePicker.date)
        WorkVC.newHomework.dueDate = text
        let db = Firestore.firestore()
        let currDoc = db.collection("users").document((LoginVC.blocks["uid"] as? String) ?? "")
        var tasks = (LoginVC.blocks["tasks"] as? [[String:Any]]) ?? [[String:Any]]()
        tasks.append(["title":"\(WorkVC.newHomework.title)", "description":"\(WorkVC.newHomework.description)", "dueDate":"\(WorkVC.newHomework.dueDate)", "isCompleted":false])
        currDoc.setData(["tasks": tasks], merge: true)
        HomeworkDueDateVC.link.tasks.append(WorkVC.newHomework)
        HomeworkDueDateVC.link.tasks = HomeworkDueDateVC.link.tasks.sorted {first, second -> Bool in
            let convertedDate1 = dateformatter.date(from: first.dueDate) ?? Date()
            let convertedDate2 = dateformatter.date(from: second.dueDate) ?? Date()
            return convertedDate1 < convertedDate2
        }
        HomeworkDueDateVC.link.tableView.reloadData()
        self.dismiss(animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        datePicker.minimumDate = Date()
    }
}
