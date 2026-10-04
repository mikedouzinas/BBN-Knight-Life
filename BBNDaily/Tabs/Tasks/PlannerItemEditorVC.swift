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
    /// The parent of this item, or its steps (HQ-2187). Lets the sheet keep a step from being dated
    /// after its parent, move steps when the parent moves earlier, and say how many go when a parent
    /// is deleted. `.none` when opened without context, in which case none of that applies.
    private let context: PlannerStepContext
    private let store: PlannerStore
    private var draft: PlannerDraft
    /// How long to wait for the server to confirm before closing anyway. See the note above.
    private let saveTimeout: TimeInterval = 8

    private let kindControl = UISegmentedControl(items: PlannerKind.allCases.map { $0.label })
    private let titleField = UITextField()
    private let datePicker = UIDatePicker()
    private let classButton = UIButton(type: .system)
    private let notesField = UITextField()
    // HQ-2185: when to remind, a time for "Custom", and a line saying why it won't show up if it won't.
    private let reminderControl = UISegmentedControl(items: ["None", "Night before", "That morning", "Custom"])
    private let remindPicker = UIDatePicker()
    private let reminderNote = UILabel()
    private var customRow = UIView()
    private var permission = ReminderPermission.unknown
    // HQ-2186: the big-deadline switch and its four countdown steps.
    private var bigRow = UIView()
    private let bigSwitch = UISwitch()
    private var rungSwitches = [LadderRung: UISwitch]()
    private var ladderBox = UIStackView()
    private var reminderBox = UIStackView()
    /// Once the student touches the Big switch, changing the kind stops changing it for them.
    private var bigTouched = false
    private lazy var saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))

    init(existing: PlannerItem? = nil, context: PlannerStepContext = .none, store: PlannerStore = .shared) {
        self.existing = existing
        self.context = context
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
        datePicker.addTarget(self, action: #selector(dueChanged), for: .valueChanged)

        reminderControl.selectedSegmentIndex = PlannerReminder.allCases.firstIndex(of: draft.reminder) ?? 1
        reminderControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 12)], for: .normal)
        reminderControl.addTarget(self, action: #selector(reminderChanged), for: .valueChanged)
        let reminderLabel = UILabel()
        reminderLabel.text = "Remind me (7 PM the night before, or 7 AM that day)"
        reminderLabel.font = .systemFont(ofSize: 13)
        reminderLabel.textColor = UIColor(named: "inverse")?.withAlphaComponent(0.7)
        reminderLabel.numberOfLines = 0
        remindPicker.datePickerMode = .dateAndTime
        remindPicker.preferredDatePickerStyle = .compact
        remindPicker.date = draft.remindAt ?? PlannerReminders.defaultCustomTime(forDueDay: PlannerItem.dayString(from: draft.dueDate), now: Date())
        remindPicker.addTarget(self, action: #selector(remindAtChanged), for: .valueChanged)
        customRow = row(label: "At", control: remindPicker)
        customRow.isHidden = draft.reminder != .custom
        reminderNote.font = .systemFont(ofSize: 13)
        reminderNote.textColor = .systemOrange
        reminderNote.numberOfLines = 0
        reminderNote.isHidden = true

        // The plain reminder choice (ordinary items).
        reminderBox = UIStackView(arrangedSubviews: [reminderLabel, reminderControl, customRow])
        reminderBox.axis = .vertical
        reminderBox.spacing = 12

        // The countdown (big deadlines): the reminder control is replaced by four switches.
        bigSwitch.isOn = draft.isBig
        bigSwitch.addTarget(self, action: #selector(bigChanged), for: .valueChanged)
        bigRow = row(label: "Big deadline (test, paper, project)", control: bigSwitch)
        ladderBox = UIStackView(arrangedSubviews: LadderRung.allCases.map { rung in
            let toggle = UISwitch()
            toggle.isOn = draft.rungs.contains(rung)
            toggle.addTarget(self, action: #selector(rungChanged), for: .valueChanged)
            rungSwitches[rung] = toggle
            return row(label: rung.label, control: toggle)
        })
        ladderBox.axis = .vertical
        ladderBox.spacing = 10
        applyBigVisibility()

        var views: [UIView] = [kindControl, titleField, dueRow, classRow, notesField,
                               bigRow, reminderBox, ladderBox, reminderNote]
        if let existing = existing, PlannerSteps.canHaveSteps(existing), context.steps.isEmpty {
            let split = UIButton(type: .system)
            split.setTitle("Split into steps…", for: .normal)
            split.addTarget(self, action: #selector(chooseStepCount), for: .touchUpInside)
            views.append(split)
        }
        if let parent = context.parent, existing != nil {
            let note = UILabel()
            note.text = "A step of \"\(parent.title)\", due \(PlannerListing.dayLabel(forDay: parent.dueDate)). It can't be dated after it."
            note.font = .systemFont(ofSize: 13)
            note.textColor = UIColor(named: "inverse")?.withAlphaComponent(0.7)
            note.numberOfLines = 0
            views.append(note)
        }
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
        PlannerReminderScheduler.permission { [weak self] permission in
            self?.permission = permission
            self?.refreshReminderNote()
        }
        refreshReminderNote()
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
        // A switch has a fixed size and would sit right beside its label; the spacer pushes it to
        // the trailing edge like every other control in the form.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: control is UISwitch ? [title, spacer, control] : [title, control])
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

    // MARK: Reminder (HQ-2185)

    @objc private func reminderChanged() {
        draft.reminder = PlannerReminder.allCases[reminderControl.selectedSegmentIndex]
        if draft.reminder == .custom {
            draft.remindAt = remindPicker.date
        }
        customRow.isHidden = draft.reminder != .custom
        if draft.reminder != .none { PlannerReminderScheduler.requestPermissionIfNeeded() }
        refreshReminderNote()
    }

    @objc private func remindAtChanged() {
        draft.remindAt = remindPicker.date
        refreshReminderNote()
    }

    @objc private func dueChanged() {
        draft.dueDate = datePicker.date
        refreshReminderNote()
    }

    /// Says why this reminder won't show up, when it won't: a moment already past, notifications
    /// off in iOS, or off in the app. Silence is the failure being avoided.
    private func refreshReminderNote() {
        let preview = draft.makeItem(id: "preview", replacing: existing)
        let text = PlannerReminders.note(for: preview, now: Date(), permission: permission,
                                         appNotificationsOn: PlannerReminderScheduler.appNotificationsOn)
        reminderNote.text = text
        reminderNote.isHidden = text == nil
    }

    @objc private func kindChanged() {
        draft.kind = PlannerKind.allCases[kindControl.selectedSegmentIndex]
        // A test is a big deadline unless the student has said otherwise; nothing else is.
        if !bigTouched && existing == nil {
            draft.isBig = draft.kind == .test
            bigSwitch.setOn(draft.isBig, animated: true)
            applyBigVisibility()
            refreshReminderNote()
        }
    }

    // MARK: Big deadline (HQ-2186)

    @objc private func bigChanged() {
        bigTouched = true
        draft.isBig = bigSwitch.isOn
        if draft.isBig { PlannerReminderScheduler.requestPermissionIfNeeded() }
        applyBigVisibility()
        refreshReminderNote()
    }

    @objc private func rungChanged() {
        draft.rungs = Set(rungSwitches.filter { $0.value.isOn }.map { $0.key })
        refreshReminderNote()
    }

    /// A big deadline's countdown replaces the plain reminder choice, so the two are never both shown.
    /// A step is never a big deadline (the countdown belongs to the deadline it is part of), so a step's
    /// sheet has no Big switch and always shows the ordinary reminder.
    private var isStep: Bool { existing?.parentId != nil }

    private func applyBigVisibility() {
        bigRow.isHidden = isStep
        ladderBox.isHidden = isStep || !draft.isBig
        reminderBox.isHidden = !isStep && draft.isBig
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

        // A step can never be dated after the deadline it belongs to (HQ-2187).
        if let problem = PlannerSteps.dateProblem(step: item, parent: context.parent) {
            alert(problem)
            return
        }
        // Moving a parent earlier moves the steps that would now be late, in the same atomic write,
        // and the student is told. Leaving them would be a plan that contradicts itself.
        let movedSteps = existing == nil ? [] : PlannerSteps.reconcile(steps: context.steps, toParentDue: item.dueDate)
        let everything = [item] + movedSteps

        // The reminder takes effect now rather than when the server answers: the write is already
        // queued on the phone, and a student who saves a test while offline should still be reminded
        // of it. If the server later refuses the write, the next planner load drops the item from
        // the cache and the reminder goes with it.
        var remindersChanged = false
        for each in everything where PlannerReminderScheduler.didSave(each) { remindersChanged = true }
        if remindersChanged { setNotifications() }
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

        let finish: (Result<Void, PlannerError>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                giveUp.cancel()
                switch result {
                case .success:
                    if !movedSteps.isEmpty {
                        ProgressHUD.colorAnimation = .green
                        ProgressHUD.succeed("Moved \(movedSteps.count) step\(movedSteps.count == 1 ? "" : "s") to match the new deadline")
                    }
                    guard let self = self, !finished else { self?.onChange?(); return }
                    finished = true
                    self.hideLoader(completion: nil)
                    self.close()
                    self.onChange?()
                case .failure(let error):
                    // The save did not happen, so neither does its reminder. Without this a student
                    // who sees "couldn't save" and cancels is still reminded at 7 PM about something
                    // that was never put on their planner.
                    self?.takeBackReminders(for: everything)
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
        if movedSteps.isEmpty { store.save(item, completion: finish) } else { store.saveAll(everything, completion: finish) }
    }

    /// Undoes the optimistic reminder from `save()`: a new item's goes away, and an edited item's goes
    /// back to what it was.
    private func takeBackReminders(for items: [PlannerItem]) {
        var changed = false
        for item in items {
            // The saved copy goes back if there was one (an edit, or a step that was moved); a brand
            // new item has nothing to go back to and is removed.
            let original = item.id == existing?.id ? existing : context.steps.first { $0.id == item.id }
            let did = original.map { PlannerReminderScheduler.didSave($0) } ?? PlannerReminderScheduler.didDelete(id: item.id)
            if did { changed = true }
        }
        if changed { setNotifications() }
    }

    @objc private func confirmDelete() {
        guard let existing = existing else { return }
        // A parent's steps go with it, and the confirmation says how many (HQ-2187).
        let stepIDs = context.steps.map { $0.id }
        let alert = UIAlertController(title: PlannerSteps.deleteMessage(parentTitle: existing.title, stepCount: stepIDs.count),
                                      message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            let ids = [existing.id] + stepIDs
            self?.store.deleteAll(ids: ids) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        var changed = false
                        for id in ids where PlannerReminderScheduler.didDelete(id: id) { changed = true }
                        if changed { self?.setNotifications() }
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

    // MARK: Split into steps (HQ-2187)

    @objc private func chooseStepCount() {
        guard let existing = existing else { return }
        let sheet = UIAlertController(title: "Split into steps", message: "How many steps?", preferredStyle: .actionSheet)
        for count in 2...PlannerSteps.maxSteps {
            sheet.addAction(UIAlertAction(title: "\(count) steps", style: .default, handler: { [weak self] _ in
                self?.proposeSteps(for: existing, count: count)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }

    /// Shows the dates before anything is saved, so the student sees what they are about to get.
    private func proposeSteps(for parent: PlannerItem, count: Int) {
        let suggestions = PlannerSteps.suggest(parentTitle: parent.title, dueDate: parent.dueDate,
                                               today: PlannerItem.dayString(from: Date()), count: count)
        guard !suggestions.isEmpty else {
            alert("There's no room to split this: it's due today or already past.")
            return
        }
        let dates = suggestions.map { PlannerListing.dayLabel(forDay: $0.dueDate) }.joined(separator: "\n")
        let confirm = UIAlertController(title: "Add \(suggestions.count) step\(suggestions.count == 1 ? "" : "s")?",
                                        message: "Evenly spaced up to the deadline:\n\(dates)\n\nYou can change each one afterwards.",
                                        preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            self?.createSteps(for: parent, suggestions: suggestions)
        }))
        present(confirm, animated: true)
    }

    private func createSteps(for parent: PlannerItem, suggestions: [StepSuggestion]) {
        guard let ids = store.newIDs(suggestions.count) else {
            alert(PlannerError.notSignedIn.message)
            return
        }
        let steps = PlannerSteps.makeSteps(for: parent, suggestions: suggestions, ids: ids)
        showLoader(text: "Adding steps...")
        var changed = false
        for step in steps where PlannerReminderScheduler.didSave(step) { changed = true }
        if changed { setNotifications() }
        store.saveAll(steps) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoader(completion: nil)
                switch result {
                case .success:
                    self?.close()
                    self?.onChange?()
                case .failure(let error):
                    // All or nothing: none were saved, so none of their reminders stay.
                    var undone = false
                    for step in steps where PlannerReminderScheduler.didDelete(id: step.id) { undone = true }
                    if undone { self?.setNotifications() }
                    self?.alert(error.message)
                }
            }
        }
    }
}
