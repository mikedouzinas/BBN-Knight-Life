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
    static var newHomework = SchoolTask(title: "Homework", description: "Nothing!", dueDate: "12/21/2005", isCompleted: false)
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
    public var selectedTask = SchoolTask(title: "", description: "", dueDate: "", isCompleted: false)
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
        let tempTasks = LoginVC.blocks["tasks"] as? [[String: Any]]
        guard tempTasks != nil else {
            return
        }
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yyyy"
        for x in tempTasks! {
            
            let dueDate = (x["dueDate"] as? String) ?? "N/A"
            let convertedDate = dateformatter.date(from: dueDate) ?? Date()
            let todayString = dateformatter.string(from: Date())
            let todayDate = dateformatter.date(from: todayString) ?? Date()
            if convertedDate >= todayDate {
                tasks.append(SchoolTask(title: (x["title"] as? String) ?? "No Title", description: (x["description"] as? String) ?? "", dueDate: (x["dueDate"] as? String) ?? "N/A", isCompleted: (x["isCompleted"] as? Bool) ?? false))
            }
        }
        tasks = tasks.sorted {first, second -> Bool in
            let convertedDate1 = dateformatter.date(from: first.dueDate) ?? Date()
            let convertedDate2 = dateformatter.date(from: second.dueDate) ?? Date()
            return convertedDate1 < convertedDate2
        }
    }
}



