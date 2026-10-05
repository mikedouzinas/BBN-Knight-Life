//
//  PlannerItemEditorVC.swift
//  BBNDaily
//
//  HQ-2181. The sheet behind the Tasks tab's + button, and behind tapping an item in the
//  Upcoming list: a kind, a title, a due date, an optional class and optional notes.
//
//  Two rules it holds to:
//
//  - A failed save never costs the student what they typed. The sheet stays open, with its text,
//    and says what went wrong.
//  - It never spins forever. Firestore reports a write done only when the server confirms it, so
//    with no signal the callback simply does not come. After `saveTimeout` the sheet stops
//    waiting and closes: the write is queued on the phone and goes through when the connection
//    does. If the server later refuses it, that is reported then.
//

import UIKit
import ProgressHUD

final class PlannerItemEditorVC: UIViewController, UITextFieldDelegate {

    /// Called after a save or delete that should refresh whatever list is showing.
    var onChange: (() -> Void)?

    private let existing: PlannerItem?
    private let store: PlannerStore
    private var draft: PlannerDraft
    /// How long to wait for the server to confirm before closing anyway. See the note above.
    private let saveTimeout: TimeInterval = 8

    private let kindControl = UISegmentedControl(items: PlannerKind.allCases.map { $0.label })
    private let titleField = UITextField()
    private let datePicker = UIDatePicker()
    private let classButton = UIButton(type: .system)
    private let notesField = UITextField()
    private lazy var saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))

    init(existing: PlannerItem? = nil, store: PlannerStore = .shared) {
        self.existing = existing
        self.store = store
        self.draft = existing.map { PlannerDraft(editing: $0) } ?? PlannerDraft.new()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existing == nil ? "New Item" : "Edit Item"
        view.backgroundColor = UIColor(named: "background")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = saveButton

        kindControl.selectedSegmentIndex = PlannerKind.allCases.firstIndex(of: draft.kind) ?? 0
        kindControl.addTarget(self, action: #selector(kindChanged), for: .valueChanged)

        configure(titleField, placeholder: "Title, e.g. Chemistry unit 4 test", text: draft.title)
        configure(notesField, placeholder: "Notes (optional)", text: draft.notes)
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.date = draft.dueDate

        classButton.contentHorizontalAlignment = .trailing
        classButton.showsMenuAsPrimaryAction = true
        refreshClassMenu()

        let dueRow = row(label: "Due", control: datePicker)
        let classRow = row(label: "Class", control: classButton)

        var views: [UIView] = [kindControl, titleField, dueRow, classRow, notesField]
        if existing != nil {
            let delete = UIButton(type: .system)
            delete.setTitle("Delete", for: .normal)
            delete.setTitleColor(.systemRed, for: .normal)
            delete.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
            views.append(delete)
        }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
        ])
        updateSaveEnabled()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if existing == nil { titleField.becomeFirstResponder() }
    }

    // MARK: Fields

    private func configure(_ field: UITextField, placeholder: String, text: String) {
        field.placeholder = placeholder
        field.text = text
        field.borderStyle = .roundedRect
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.delegate = self
    }

    private func row(label: String, control: UIView) -> UIView {
        let title = UILabel()
        title.text = label
        title.textColor = UIColor(named: "inverse")
        title.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [title, control])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }

    /// The student's own classes, A to G. Anything unset or marked Free is not worth attaching a
    /// test to, so it is not offered (ClassIdentity.isFree is the app's one definition of free).
    private func classOptions() -> [(block: String, name: String)] {
        ["A", "B", "C", "D", "E", "F", "G"].compactMap { letter in
            guard let assignment = LoginVC.blocks[letter] as? String, assignment.contains("~") else { return nil }
            let subject = assignment.getValues()[0]
            return ClassIdentity.isFree(subject) ? nil : (letter, subject)
        }
    }

    private func refreshClassMenu() {
        let none = UIAction(title: "None", state: draft.classBlock == nil ? .on : .off) { [weak self] _ in
            self?.draft.classBlock = nil
            self?.refreshClassMenu()
        }
        let options = classOptions().map { option in
            UIAction(title: "\(option.block) · \(option.name)", state: draft.classBlock == option.block ? .on : .off) { [weak self] _ in
                self?.draft.classBlock = option.block
                self?.refreshClassMenu()
            }
        }
        classButton.menu = UIMenu(children: [none] + options)
        let current = classOptions().first { $0.block == draft.classBlock }
        classButton.setTitle(current.map { "\($0.block) · \($0.name)" } ?? "None", for: .normal)
    }

    @objc private func kindChanged() {
        draft.kind = PlannerKind.allCases[kindControl.selectedSegmentIndex]
    }

    @objc private func titleChanged() { updateSaveEnabled() }

    private func updateSaveEnabled() {
        let text = titleField.text ?? ""
        saveButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let limit = textField === titleField ? FieldLimits.plannerTitle : FieldLimits.plannerNotes
        let current = (textField.text ?? "") as NSString
        return current.replacingCharacters(in: range, with: string).count <= limit
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: Actions

    @objc private func cancel() { close() }

    private func close() {
        view.endEditing(true)
        if let nav = navigationController { nav.dismiss(animated: true) } else { dismiss(animated: true) }
    }

    private func readFields() {
        draft.title = titleField.text ?? ""
        draft.notes = notesField.text ?? ""
        draft.dueDate = datePicker.date
    }

    private func alert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func save() {
        view.endEditing(true)
        readFields()
        guard let id = existing?.id ?? store.newID() else {
            alert(PlannerError.notSignedIn.message)
            return
        }
        let item = draft.makeItem(id: id, replacing: existing)
        // Tell the student what is wrong before spending a round trip finding out.
        if let reason = item.validationError() {
            alert(reason.message)
            return
        }

        showLoader(text: "Saving...")
        var finished = false
        let giveUp = DispatchWorkItem { [weak self] in
            guard let self = self, !finished else { return }
            finished = true
            self.hideLoader(completion: nil)
            self.close()
            self.onChange?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + saveTimeout, execute: giveUp)

        store.save(item) { [weak self] result in
            DispatchQueue.main.async {
                giveUp.cancel()
                switch result {
                case .success:
                    guard let self = self, !finished else { self?.onChange?(); return }
                    finished = true
                    self.hideLoader(completion: nil)
                    self.close()
                    self.onChange?()
                case .failure(let error):
                    if finished {
                        // The sheet already closed on the timeout; there is nothing to keep open.
                        ProgressHUD.colorAnimation = .red
                        ProgressHUD.failed(error.message)
                        self?.onChange?()
                    } else {
                        finished = true
                        self?.hideLoader(completion: nil)
                        self?.alert(error.message)   // sheet and text stay
                    }
                }
            }
        }
    }

    @objc private func confirmDelete() {
        guard let existing = existing else { return }
        let alert = UIAlertController(title: "Delete \"\(existing.title)\"?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.store.delete(id: existing.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.close()
                        self?.onChange?()
                    case .failure(let error):
                        self?.alert(error.message)
                    }
                }
            }
        }))
        present(alert, animated: true)
    }
}
