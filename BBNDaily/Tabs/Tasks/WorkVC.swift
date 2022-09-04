//
//  WorkVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 1/31/22.
//

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit
import SkeletonView

class WorkVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        HomeworkTitleVC.link = self
        HomeworkInfoVC.link = self
        HomeworkDueDateVC.link = self
        self.performSegue(withIdentifier: "newhomework", sender: nil)
    }
    static var newHomework = SchoolTask(title: "Homework", description: "Nothing!", dueDate: "12/21/2005", isCompleted: false, index: 0)
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskCell.identifier, for: indexPath) as? TaskCell else {
            fatalError()
        }
        cell.configure(with: tasks[indexPath.row])
        return cell
    }
    public var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(TaskCell.self, forCellReuseIdentifier: TaskCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        return tableView
    } ()
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedTask = tasks[indexPath.row]
        selectedIndex = indexPath.row
        detailedWorkVC.link = self
        self.performSegue(withIdentifier: "largeWork", sender: nil)
    }
    public var selectedIndex = 0
    public var selectedTask = SchoolTask(title: "", description: "", dueDate: "", isCompleted: false, index: 0)
    public var tasks = [SchoolTask]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // make this a to do list instead
        view.backgroundColor = UIColor(named: "background")
        tableView.backgroundColor = UIColor(named: "background")
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        sortTasks()
    }
    func sortTasks() {
        tasks = [SchoolTask]()
        let tempTasks = LoginVC.blocks["tasks"] as? [[String: Any]]
        guard tempTasks != nil else {
            return
        }
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yyyy"
        var index = 0
        for x in tempTasks! {
            let dueDate = (x["dueDate"] as? String) ?? "N/A"
            let convertedDate = dateformatter.date(from: dueDate) ?? Date()
            let todayString = dateformatter.string(from: Date())
            let todayDate = dateformatter.date(from: todayString) ?? Date()
            if convertedDate >= todayDate {
                tasks.append(SchoolTask(title: (x["title"] as? String) ?? "No Title", description: (x["description"] as? String) ?? "", dueDate: (x["dueDate"] as? String) ?? "N/A", isCompleted: (x["isCompleted"] as? Bool) ?? false, index: index))
            }
            index += 1
        }
        tasks = tasks.sorted {first, second -> Bool in
            let convertedDate1 = dateformatter.date(from: first.dueDate) ?? Date()
            let convertedDate2 = dateformatter.date(from: second.dueDate) ?? Date()
            return convertedDate1 < convertedDate2
        }
        checkIfEmpty()
    }
//    private func handleMarkAsCompleted() {
//        let refreshAlert = UIAlertController(title: "Delete Task", message: "Are you sure? This action cannot be undone.", preferredStyle: .alert)
//        refreshAlert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { [self] (action: UIAlertAction!) in
//            let tempTasks = LoginVC.blocks["tasks"] as? [[String: Any]]
//            let index = selectedTask.index
//            if var tempTasks = tempTasks {
//                tempTasks.remove(at: index)
//                LoginVC.blocks["tasks"] = tempTasks
//                let db = Firestore.firestore()
//                let currDoc = db.collection("users").document((LoginVC.blocks["uid"] as? String) ?? "")
//                currDoc.setData(["tasks": tempTasks], merge: true)
//                sortTasks()
//                tableView.reloadData()
//            }
//        }))
//        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
//        }))
//        present(refreshAlert, animated: true, completion: nil)
//    }
//    func tableView(_ tableView: UITableView,
//                   editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
//        return .none
//    }
//    func tableView(_ tableView: UITableView,
//                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//
//
//        let complete = UIContextualAction(style: .normal,
//                                          title: "Delete") { [weak self] (action, view, completionHandler) in
//            guard let self = self else {
//                return
//            }
//            self.selectedTask = self.tasks[indexPath.row]
//            self.handleMarkAsCompleted()
//            completionHandler(true)
//        }
//        complete.backgroundColor = .systemBlue
//
//        let configuration = UISwipeActionsConfiguration(actions: [complete])
//
//
//        return configuration
//    }
    func checkIfEmpty() {
        if tasks.isEmpty {
            tableView.setEmptyMessage("No Tasks! Add one by pressing the plus in the top right corner.")
        }
        else {
            tableView.restore()
            tableView.separatorStyle = .none
        }
    }
}



