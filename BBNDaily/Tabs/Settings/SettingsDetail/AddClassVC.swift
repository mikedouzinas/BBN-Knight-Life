//
//  AddClassVC.swift
//  BBNDaily
//
//  HQ-658 (scoped): one screen to add a class instead of four (ClassNameVC ->
//  TeacherNameVC -> RoomNumVC -> DaySelectVC). Deliberately does NOT touch the
//  tilde-joined class key or migrate existing documents - that's a live production data
//  migration with real backward-compatibility risk (old app versions still expect the
//  current key shape), and it's its own conversation with Mike, not something to fold
//  into a UI change. Editing an existing class still goes through the original chain,
//  unchanged - the member-migration-on-rename logic there is already correct and this
//  doesn't need to touch it.
//
//  What this DOES fix: "Match an existing class case- and punctuation-insensitively
//  before making a new one" - the ticket's actual complaint that two students typing
//  "Mr Smith" and "Mr. Smith" end up in different classes that can't see each other.

import UIKit
import Firebase
import ProgressHUD

class AddClassVC: UIViewController, UITextFieldDelegate {
    var link: ClassesOptionsPopupVC!

    private let subjectField = AddClassVC.makeField(placeholder: "Subject")
    private let teacherField = AddClassVC.makeField(placeholder: "Teacher")
    private let roomField = AddClassVC.makeField(placeholder: "Room")

    private let mondaySwitch = UISwitch()
    private let tuesdaySwitch = UISwitch()
    private let wednesdaySwitch = UISwitch()
    private let thursdaySwitch = UISwitch()
    private let fridaySwitch = UISwitch()

    private static func makeField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.autocorrectionType = .no
        return field
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Class"
        view.backgroundColor = UIColor(named: "background")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))

        for field in [subjectField, teacherField, roomField] { field.delegate = self }

        let stack = UIStackView(arrangedSubviews: [
            labeled("Subject", subjectField),
            labeled("Teacher", teacherField),
            labeled("Room", roomField),
            dayRow(),
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
        ])

        for daySwitch in [mondaySwitch, tuesdaySwitch, wednesdaySwitch, thursdaySwitch, fridaySwitch] {
            daySwitch.isOn = true
        }

        subjectField.becomeFirstResponder()
    }

    private func labeled(_ text: String, _ field: UITextField) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        let column = UIStackView(arrangedSubviews: [label, field])
        column.axis = .vertical
        column.spacing = 4
        return column
    }

    private func dayRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        for (name, daySwitch) in [("M", mondaySwitch), ("T", tuesdaySwitch), ("W", wednesdaySwitch), ("Th", thursdaySwitch), ("F", fridaySwitch)] {
            let label = UILabel()
            label.text = name
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = .systemGray
            label.textAlignment = .center
            let column = UIStackView(arrangedSubviews: [label, daySwitch])
            column.axis = .vertical
            column.alignment = .center
            column.spacing = 4
            row.addArrangedSubview(column)
        }
        return row
    }

    // One screen, three fields, three different length limits - TextFieldVC's single
    // maxLength only fits one field per screen, so this implements the same idea by hand.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let limit: Int
        switch textField {
        case subjectField: limit = 25
        case teacherField: limit = 50
        default: limit = 25
        }
        let newString = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        return newString.count <= limit
    }

    @objc private func save() {
        let subject = (subjectField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let teacherInput = (teacherField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let roomInput = (roomField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !subject.isEmpty, !subject.contains("~"), !subject.contains("/"),
              !teacherInput.contains("~"), !teacherInput.contains("/"),
              !roomInput.contains("~"), !roomInput.contains("/") else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("Enter at least a subject. (Don't use any ~ or /)")
            return
        }

        let teacher = teacherInput.isEmpty ? "N/A" : teacherInput
        let room = roomInput.isEmpty ? "N/A" : roomInput

        if let match = findExistingMatch(subject: subject, teacher: teacher, room: room) {
            confirmJoinExisting(match: match, typedSubject: subject, typedTeacher: teacher, typedRoom: room)
        } else {
            performSave(subject: subject, teacher: teacher, room: room)
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func findExistingMatch(subject: String, teacher: String, room: String) -> ClassModel? {
        let key = [normalize(subject), normalize(teacher), normalize(room)]
        return link.Classes.first {
            [normalize($0.Subject), normalize($0.Teacher), normalize($0.Room)] == key
        }
    }

    private func confirmJoinExisting(match: ClassModel, typedSubject: String, typedTeacher: String, typedRoom: String) {
        let alert = UIAlertController(
            title: "This class already exists",
            message: "\"\(match.Subject)\" with \(match.Teacher) in \(match.Room) is already set up for this block. Join that one instead of creating a near-duplicate that can't see its roster?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Join Existing", style: .default, handler: { [weak self] _ in
            self?.performSave(subject: match.Subject, teacher: match.Teacher, room: match.Room)
        }))
        alert.addAction(UIAlertAction(title: "Create New Anyway", style: .default, handler: { [weak self] _ in
            self?.performSave(subject: typedSubject, teacher: typedTeacher, room: typedRoom)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func performSave(subject: String, teacher: String, room: String) {
        let block = ClassesOptionsPopupVC.newClass.Block
        let finalString = "\(subject)~\(teacher)~\(room)~\(block)"

        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("Please sign out and back in to fix your account")
            return
        }
        if link.Classes.contains(where: { "\($0.Subject)~\($0.Teacher)~\($0.Room)~\($0.Block)" == finalString }) {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("That exact class already exists.")
            return
        }

        showLoader(text: "Adding class...")
        let db = Firestore.firestore()
        let currDoc = db.collection("classes").document(finalString)
        // Unlike the old create path, the creator is added to members here - the same
        // fix HQ-649 made to removal applies to creation: a class with no members yet
        // shouldn't start life with its own creator missing from its roster.
        let data: [String: Any] = [
            "name": finalString,
            "owner": LoginVC.email,
            "block": block.uppercased(),
            "monday": mondaySwitch.isOn,
            "tuesday": tuesdaySwitch.isOn,
            "wednesday": wednesdaySwitch.isOn,
            "thursday": thursdaySwitch.isOn,
            "friday": fridaySwitch.isOn,
            "members": [["name": LoginVC.fullName, "email": LoginVC.email, "uid": uid]],
        ]
        currDoc.setData(data, completion: { [weak self] err in
            guard let self = self else { return }
            self.hideLoader(completion: {
                if let err = err {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Failed to add class, please try again.")
                    print(err)
                } else {
                    let selectedRow = ClassModel(Subject: subject, Teacher: teacher, Room: room, Block: block)
                    self.link.Classes.append(selectedRow)
                    self.link.filteredClasses = self.link.Classes
                    self.link.tableView.reloadData()
                    self.navigationController?.popViewController(animated: true)
                }
            })
        })
    }
}
