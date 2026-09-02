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
    // HQ-116. `SchoolTask.index` is this task's position in the unfiltered
    // LoginVC.blocks["tasks"] array (see sortTasks below), which is how a row in the
    // filtered, sorted display list maps back to the raw array entry to remove.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        // Checked, not interpolated: an empty uid becomes document(""), which Firestore
        // treats as a fatal programmer error rather than a failed write. Checked BEFORE the
        // local array is mutated, so a delete that cannot be persisted does not vanish from
        // the screen and come back on the next launch.
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("Please sign out and back in to fix your account")
            return
        }
        let removedIndex = tasks[indexPath.row].index
        var rawTasks = (LoginVC.blocks["tasks"] as? [[String: Any]]) ?? []
        guard removedIndex >= 0, removedIndex < rawTasks.count else { return }
        rawTasks.remove(at: removedIndex)
        LoginVC.blocks["tasks"] = rawTasks
        // setData(merge:) rather than updateData, which fails outright on a record that has
        // not been created yet, and a completion handler so a failed delete says so instead
        // of reappearing at the next launch with no explanation.
        Firestore.firestore().collection("users").document(uid)
            .setData(["tasks": rawTasks], merge: true) { error in
                guard let error = error else { return }
                print("task delete failed: \(error)")
                ProgressHUD.colorAnimation = .red
                ProgressHUD.failed("Couldn't delete that task. It may come back.")
            }
        // Re-derive from the array just written rather than removing this one row by hand,
        // so every other task's `index` (now shifted) is correct before the next delete.
        sortTasks()
        tableView.reloadData()
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



