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
        sortTasks(tempTasks: (tempTasks ?? [[String: Any]]()))
    }
//    do stuff here
    func sortTasks (tempTasks: [[String: Any]]) {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yyyy"
        tasks.removeAll()
        for x in tempTasks {
            
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
        tableView.reloadData()
    }
    private func handleMarkAsCompleted() {
//        complete
        var tempTasks = LoginVC.blocks["tasks"] as? [[String: Any]]
        tempTasks?.remove(at: 0)// fix to remove the correct one
        let db = Firestore.firestore()
        let currDoc = db.collection("users").document((LoginVC.blocks["uid"] as? String) ?? "")
        currDoc.setData(["tasks": tempTasks], merge: true)
        sortTasks(tempTasks: (tempTasks ?? [[String: Any]]()))
    }

    func tableView(_ tableView: UITableView,
                   editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    func tableView(_ tableView: UITableView,
                       trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        
        let complete = UIContextualAction(style: .normal,
                                       title: "Mark as Complete") { [weak self] (action, view, completionHandler) in
                                        self?.handleMarkAsCompleted()
                                        completionHandler(true)
        }
        complete.backgroundColor = .systemBlue

        let configuration = UISwipeActionsConfiguration(actions: [complete])
        

        return configuration
    }
}

struct SchoolTask {
    var title: String
    var description: String
    var dueDate: String
    let isCompleted: Bool
}

class TaskCell: UITableViewCell {
    static let identifier = "TaskCell"
    
    private let TitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.textColor = UIColor(named: "inverse")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.minimumScaleFactor = 0.5
        label.text = "ndiewniedneddeewjd"
        label.textAlignment = .left
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let DescriptionLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor(named: "inverse")
        label.minimumScaleFactor = 0.8
        label.textAlignment = .left
        label.text = "ndiewniedneddeewjd"
        label.skeletonCornerRadius = 4
        label.isSkeletonable = true
        return label
    } ()
    private let DateLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.textColor = UIColor(named: "inverse")
        label.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 8
        label.padding(2, 2, 8, 8)
//        let spacing: CGFloat = 8.0
//        label.paddingLeft = spacing
//        label.paddingRight = spacing
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.isSkeletonable = true
        label.numberOfLines = 2
        return label
    } ()
    public let backView: UIView = {
        let backview = UIView()
        backview.translatesAutoresizingMaskIntoConstraints = false
        backview.isSkeletonable = true
        backview.layer.cornerRadius = 16
        backview.layer.masksToBounds = true
        backview.skeletonCornerRadius = 16
        backview.backgroundColor = UIColor(named: "current-cell")?.withAlphaComponent(0.1)
        return backview
    } ()
//    public let checkBox: UIImageView = {
//        let img = UIImageView()
//        img.image = UIImage(named: "incomplete")
//        img.translatesAutoresizingMaskIntoConstraints = false
//        img.isSkeletonable = true
//        img.skeletonCornerRadius = 8
//        img.tintColor = UIColor(named: "inverse")
//        return img
//    } ()
    public var isComplete = false
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(backView)
//        contentView.addSubview(checkBox)
        contentView.addSubview(TitleLabel)
        contentView.addSubview(DescriptionLabel)
        contentView.addSubview(DateLabel)
        contentView.backgroundColor = UIColor(named: "background")
        
        isSkeletonable = true
        contentView.isSkeletonable = true
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    var constraint = NSLayoutConstraint()
    override func layoutSubviews() {
        super.layoutSubviews()
        
        backView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 5).isActive = true
        backView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true
        backView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        backView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
//swipe motion to check off completing tasks or delete, options
        TitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
//        checkBox.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
//        checkBox.rightAnchor.constraint(equalTo: TitleLabel.leftAnchor, constant: -10).isActive = true
//        checkBox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
//        checkBox.heightAnchor.constraint(equalToConstant: 30).isActive = true
//        checkBox.widthAnchor.constraint(equalTo: checkBox.heightAnchor).isActive = true
        
        TitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
        TitleLabel.centerXAnchor.constraint(equalTo: DescriptionLabel.centerXAnchor).isActive = true
        TitleLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        TitleLabel.rightAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true

        DescriptionLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10).isActive = true
        DescriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
        DescriptionLabel.leftAnchor.constraint(equalTo: TitleLabel.leftAnchor).isActive = true
        DescriptionLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20).isActive = true
        
        DateLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20).isActive = true
        DateLabel.centerYAnchor.constraint(equalTo: TitleLabel.centerYAnchor).isActive = true
        DateLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
        DateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        DateLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        DateLabel.leftAnchor.constraint(greaterThanOrEqualTo: contentView.centerXAnchor, constant: 5).isActive = true

    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure (with viewModel: SchoolTask){
        TitleLabel.text = "\(viewModel.title)"
        DateLabel.text = "\(viewModel.dueDate.stringDateFromMultipleFormats(preferredFormat: 6) ?? "")"
        DescriptionLabel.text = viewModel.description
    }
}

class HomeworkTitleVC: TextFieldVC, UITextFieldDelegate {
    static var link: WorkVC!
    @IBAction func pressed(_ sender: Any) {
        guard var text = TextField.text, text.trimmingCharacters(in: .whitespacesAndNewlines) != "", !text.contains("~"), !text.contains("/") else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("Please complete fields! (Don't use any ~ or /)")
            return
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkVC.newHomework.title = text
        self.performSegue(withIdentifier: "teacher", sender: nil)
    }
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    func hideKeyboardWhenTappedAbove() {
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tap.delegate = self
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.location(in: view).y > TextField.frame.origin.y && touch.location(in: view).y < TextField.frame.maxY {
            return false
        }
        view.unbindToKeyboard()
        view.endEditing(true)
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAbove()
        TextField.delegate = self
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        TextField.resignFirstResponder()
        dismissKeyboard()
        return true
    }
    @IBOutlet weak var TextField: UITextField!
    
}
class HomeworkInfoVC: TextFieldVC, UITextFieldDelegate {
    static var link: WorkVC!
    @IBAction func pressed(_ sender: Any) {
        guard var text = TextField.text, text.trimmingCharacters(in: .whitespacesAndNewlines) != "", !text.contains("~"), !text.contains("/") else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.showFailed("Please complete fields! (Don't use any ~ or /)")
            return
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkVC.newHomework.description = text
        self.performSegue(withIdentifier: "room", sender: nil)
    }
    func hideKeyboardWhenTappedAbove() {
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tap.delegate = self
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        TextField.resignFirstResponder()
        dismissKeyboard()
        return true
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.location(in: view).y > TextField.frame.origin.y && touch.location(in: view).y < TextField.frame.maxY {
            return false
        }
        view.unbindToKeyboard()
        view.endEditing(true)
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAbove()
        TextField.delegate = self
    }
    @IBOutlet weak var TextField: UITextField!
    
}

class HomeworkDueDateVC: TextFieldVC, UITextFieldDelegate {
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
        LoginVC.blocks["tasks"] = tasks
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

class detailedWorkVC: UIViewController {
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var detailedTextView: UITextView!
    static var link: WorkVC!
    @IBAction func removeTask(_ sender: Any) {
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        print("\(detailedWorkVC.link.selectedTask.dueDate)")
        dateLabel.text = "Due \(detailedWorkVC.link.selectedTask.dueDate.stringDateFromMultipleFormats(preferredFormat: 7) ?? "")"

        detailedTextView.text = "\(detailedWorkVC.link.selectedTask.description)"
        self.title = "\(detailedWorkVC.link.selectedTask.title)"
    }
}
