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

// HQ-779: Tasks is now the classes meeting on the next school day, not a freeform
// to-do list. "Next school day" is worked out with resolveDay(date:) - the one
// resolver the rest of the app already uses for the calendar and notifications -
// rather than a second, separate notion of the school calendar living here.
class WorkVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // Section 0 is tomorrow's classes (HQ-779), section 1 is what the student has planned
    // (HQ-2181): tests, homework, games and appointments, from PlannerStore.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? entries.count : plannerRows.count
    }
    // A header only on a section that has rows, so an empty one does not leave a title with
    // nothing under it.
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return entries.isEmpty ? nil : "Classes" }
        return plannerRows.isEmpty ? nil : "Upcoming"
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        // Said out loud: an empty Upcoming list that is really a failed load looks exactly like
        // "nothing planned", and a student would stop trusting it the first time it was wrong.
        return section == 1 && plannerLoadFailed ? "Couldn't load your items. Pull down to retry." : nil
    }
    // HQ-779 turned this button into a silent refresh, which to a student looked like a + that
    // does nothing. HQ-2181 gives it its job back: add a test, homework, game or appointment.
    // The refresh it used to do is not lost - viewWillAppear already re-runs
    // loadNextSchoolDay(), which is what catches an app left open across midnight.
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        presentPlannerEditor(for: nil)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: PlannerItemCell.identifier, for: indexPath) as? PlannerItemCell,
                  plannerRows.indices.contains(indexPath.row) else {
                return UITableViewCell()
            }
            let row = plannerRows[indexPath.row]
            let item = row.item
            cell.configure(with: item, today: PlannerItem.dayString(from: Date()), depth: row.depth, progress: row.progress)
            cell.onCheckBoxTapped = { [weak self] in self?.togglePlannerItem(id: item.id) }
            return cell
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TaskCell.identifier, for: indexPath) as? TaskCell else {
            fatalError()
        }
        cell.configure(with: entries[indexPath.row])
        cell.onCheckBoxTapped = { [weak self] in
            self?.toggleCompleted(at: indexPath.row)
        }
        return cell
    }
    public var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(TaskCell.self, forCellReuseIdentifier: TaskCell.identifier)
        tableView.register(PlannerItemCell.self, forCellReuseIdentifier: PlannerItemCell.identifier)
        tableView.backgroundColor = UIColor(named: "background")
        return tableView
    } ()
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 1 ? 72 : 100
    }
    // Upcoming items swipe: right to mark done, left to delete (HQ-116 had delete-by-swipe
    // before HQ-779 removed the freeform list). Classes have nothing to delete, so no swipes.
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, plannerRows.indices.contains(indexPath.row) else { return nil }
        let id = plannerRows[indexPath.row].item.id
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.requestDeletePlannerItem(id: id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, plannerRows.indices.contains(indexPath.row) else { return nil }
        let item = plannerRows[indexPath.row].item
        let action = UIContextualAction(style: .normal, title: item.completed ? "Not done" : "Done") { [weak self] _, _, done in
            self?.togglePlannerItem(id: item.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
    // HQ-116's swipe-to-delete doesn't carry over: it removed a user-created entry from
    // LoginVC.blocks["tasks"], which HQ-779 replaces entirely with per-class homework
    // entries derived from the day's schedule - there's no "task" a student added and
    // can remove. Clearing a class's homework text already reaches the same end state:
    // persistEntries() below only keeps entries with real content, so an emptied entry
    // isn't written back either.
    //
    // Tapping the row (anywhere but the checkbox) opens quick entry for that class's
    // homework - type it, tap out, done. Not a separate detail screen.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            guard plannerRows.indices.contains(indexPath.row) else { return }
            presentPlannerEditor(for: plannerRows[indexPath.row].item)
            return
        }
        guard entries.indices.contains(indexPath.row), entries[indexPath.row].holdsHomework else { return }
        presentHomeworkEntry(at: indexPath.row)
    }

    // A keyword match on the subject, not a real classification - there is no dedicated
    // "does this subject assign homework" flag anywhere in the class data today. Good
    // enough for the one case asked for (art classes); worth becoming a real field on the
    // class document if the list of no-homework subjects grows past this.
    private static let noHomeworkKeywords = ["art", "ceramics", "painting", "drawing", "sculpture", "photography", "studio"]
    private static func isArtClass(_ subject: String) -> Bool {
        let lowered = subject.lowercased()
        return noHomeworkKeywords.contains { lowered.contains($0) }
    }

    /// The subject Tasks should list for one of the student's blocks, or nil when the block has
    /// nothing to list: nothing set, or set to Free.
    ///
    /// A Free block is stored like any other class (`Free~~~D`, or `Free~NA~NA~G` from older
    /// hand-entered data), so "has a `~`" alone lets it through and Tomorrow's Classes showed a
    /// homework row for a period the student does not have. `ClassIdentity.isFree` is the app's
    /// single definition of free (Free, Unscheduled, Study Hall, Open, and so on); this asks it
    /// rather than keeping a second list. A course whose name merely contains a free-ish word
    /// ("Free Speech in America") is still a course there, so it is still listed here.
    static func listedSubject(forAssignment assignment: String) -> String? {
        guard assignment.contains("~") else { return nil }
        let subject = assignment.getValues()[0]
        return ClassIdentity.isFree(subject) ? nil : subject
    }

    private var entries = [HomeworkEntry]()
    private var resolvedDateKey = ""
    // HQ-2181: what the student has planned, in display order, and whether the last load failed.
    private var plannerItems = [PlannerItem]() {
        // The list shown is the items with steps under their parents (HQ-2187); it is rebuilt from
        // the items every time they change, so the two can't drift.
        didSet { plannerRows = PlannerSteps.rows(plannerItems, today: PlannerItem.dayString(from: Date())) }
    }
    private var plannerRows = [PlannerListRow]()
    private var plannerLoadFailed = false
    // HQ-2184: Tomorrow (the classes list, as before) or This Week (the game plan).
    private enum Mode { case tomorrow, week }
    private var mode = Mode.tomorrow
    private var weekMonday = PlannerWeek.monday(for: Date())
    // The Tomorrow view's title ("Tomorrow's Classes" or "Tuesday's Classes"), kept so the title can
    // follow the mode. loadNextSchoolDay() runs on refresh and on every reappear, in either mode, and
    // setting the title directly there put "Tomorrow's Classes" over the week view.
    private var tomorrowTitle = "Tomorrow's Classes"
    private func applyTitle() {
        navigationItem.title = mode == .week ? "This Week" : tomorrowTitle
    }
    private let weekSource = PlannerWeekDataSource()
    private let modeHeader = PlannerWeekHeaderView(frame: CGRect(x: 0, y: 0, width: 0, height: PlannerWeekHeaderView.tomorrowHeight))
    // Why the classes section is empty, if it is: the message shown when there is nothing else
    // on screen either.
    private var classesEmptyMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        tableView.backgroundColor = UIColor(named: "background")
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        // The footer on a failed load says "pull down to retry", so there has to be something to
        // pull. Reloads both lists: the classes too, in case the app was left open across midnight.
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh
        // HQ-2184: Tomorrow | This Week.
        modeHeader.onModeChanged = { [weak self] week in self?.setMode(week ? .week : .tomorrow) }
        modeHeader.onPreviousWeek = { [weak self] in self?.moveWeek(by: -1) }
        modeHeader.onNextWeek = { [weak self] in self?.moveWeek(by: 1) }
        weekSource.onSelectItem = { [weak self] item in self?.presentPlannerEditor(for: item) }
        modeHeader.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: PlannerWeekHeaderView.tomorrowHeight)
        tableView.tableHeaderView = modeHeader
        // HQ-2182: what the four colors mean.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"), style: .plain, target: self, action: #selector(showLegend))
        navigationItem.leftBarButtonItem?.accessibilityLabel = "What the colors mean"
        loadNextSchoolDay()
    }

    @objc private func showLegend() {
        present(UINavigationController(rootViewController: PlannerLegendVC()), animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Cheap and idempotent - re-running this if the tab is just being re-shown
        // the same day produces the same list, and catches a midnight rollover if
        // the app was left open.
        loadNextSchoolDay()
        loadPlanner()
    }

    // Walks forward from tomorrow using resolveDay(date:) until it finds a day with
    // real blocks. Capped at 14 days so a schedule-data gap fails loud (an empty list
    // with a message) instead of looping or hanging - a school year is never actually
    // out that long without at least one resolvable day.
    func loadNextSchoolDay() {
        let calendar = Calendar.current
        var checkDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var resolved: ResolvedDay?
        for _ in 0..<14 {
            let candidate = resolveDay(date: checkDate)
            if !candidate.blocks.isEmpty {
                resolved = candidate
                break
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
        }

        guard let resolved = resolved else {
            entries = []
            resolvedDateKey = ""
            tableView.reloadData()
            classesEmptyMessage = "Couldn't find an upcoming school day with classes."
            updateEmptyState()
            return
        }

        // "Tomorrow" when the resolved day really is tomorrow (the common case); the
        // weekday name instead when a weekend or a break pushed it further out, so the
        // title never says "Tomorrow" about a day that isn't.
        let isTomorrow = calendar.isDate(resolved.date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        tomorrowTitle = isTomorrow ? "Tomorrow's Classes" : "\(resolved.weekdayName.capitalized)'s Classes"
        applyTitle()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d" // same key format resolveDay itself uses
        resolvedDateKey = dateFormatter.string(from: resolved.date)

        let stored = (LoginVC.blocks["classHomework"] as? [[String: Any]]) ?? []

        var built = [HomeworkEntry]()
        for scheduleBlock in resolved.blocks {
            let letter = scheduleBlock.block.uppercased()
            let assignment = (LoginVC.blocks[letter] as? String) ?? ""
            // Only this student's own classes - not every block the school runs that day, and
            // not a block the student has marked Free (HQ-2188).
            guard let subject = Self.listedSubject(forAssignment: assignment) else { continue }
            // Free that day: this student has a class in this letter block, but
            // classMeetingDays says it doesn't meet on this specific weekday. Nothing to
            // do homework for, so no row - not a row that opens an empty prompt.
            if resolved.weekdayIndex >= 0 && resolved.weekdayIndex <= 4,
               let meetsThisWeekday = LoginVC.classMeetingDays[letter.lowercased()]?[resolved.weekdayIndex],
               !meetsThisWeekday {
                continue
            }
            let existing = stored.first { ($0["block"] as? String) == letter && ($0["date"] as? String) == resolvedDateKey }
            built.append(HomeworkEntry(
                block: letter,
                subject: subject,
                date: resolvedDateKey,
                text: (existing?["text"] as? String) ?? "",
                completed: (existing?["completed"] as? Bool) ?? false,
                holdsHomework: !Self.isArtClass(subject)
            ))
        }

        applySortedEntries(built)

        classesEmptyMessage = entries.isEmpty ? "No classes set up yet - add them in Settings." : nil
        updateEmptyState()
    }

    // The empty message covers the whole table, so it may only show when BOTH lists are empty.
    // Showing "no classes" over a student's upcoming tests would hide them.
    private func updateEmptyState() {
        // The week view has its own empty states ("Nothing planned"); a table-wide message here
        // would sit on top of it.
        if mode == .week {
            tableView.restore()
            tableView.separatorStyle = .none
            return
        }
        if entries.isEmpty && plannerItems.isEmpty {
            tableView.setEmptyMessage(classesEmptyMessage ?? "Nothing coming up. Tap + to add a test, homework, game or appointment.")
        } else {
            tableView.restore()
            tableView.separatorStyle = .none
        }
    }

    // MARK: - Planner (HQ-2181)

    // Each load takes a number, and only the newest is allowed to apply. Without it a slow
    // response from an earlier load lands after a newer one and puts back an item that was
    // just deleted or un-completes one that was just finished.
    private var plannerLoadGeneration = 0

    private func loadPlanner() {
        plannerLoadGeneration += 1
        let generation = plannerLoadGeneration
        let window = PlannerListing.loadWindow()
        PlannerStore.shared.items(from: window.start, through: window.end) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, generation == self.plannerLoadGeneration else { return }
                switch result {
                case .success(let items):
                    self.plannerLoadFailed = false
                    self.plannerItems = PlannerListing.ordered(items, today: PlannerItem.dayString(from: Date()))
                    // HQ-2185: reminders are rebuilt from what was just read, but only if one could differ.
                    if PlannerReminderScheduler.didLoad(items: items, window: window) { self.setNotifications() }
                case .failure(let error):
                    if case .notSignedIn = error {
                        // Account not loaded yet: nothing to show, and nothing to apologise for.
                        self.plannerItems = []
                        self.plannerLoadFailed = false
                    } else {
                        // Keep what is already on screen and say the load failed (see the footer).
                        self.plannerLoadFailed = true
                    }
                }
                if self.mode == .week { self.rebuildWeek() } else { self.tableView.reloadData() }
                self.updateEmptyState()
                self.tableView.refreshControl?.endRefreshing()
            }
        }
    }

    // MARK: - Week (HQ-2184)

    private func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        if newMode == .week {
            weekMonday = PlannerWeek.monday(for: Date())
            tableView.dataSource = weekSource
            tableView.delegate = weekSource
            applyTitle()
            rebuildWeek()
        } else {
            tableView.dataSource = self
            tableView.delegate = self
            loadNextSchoolDay()      // sets the title and the list as before
            tableView.reloadData()
        }
        updateModeHeader()
        updateEmptyState()
    }

    private func moveWeek(by weeks: Int) {
        weekMonday = PlannerWeek.shift(weekMonday, byWeeks: weeks)
        rebuildWeek()
        updateModeHeader()
    }

    /// Weeks wholly inside what has been loaded. Going past either end would show empty days that
    /// are only empty because nothing was read for them, which looks exactly like "nothing planned".
    private func canShow(weekStarting monday: Date) -> Bool {
        let window = PlannerListing.loadWindow()
        let start = PlannerItem.dayString(from: monday)
        let end = PlannerItem.dayString(from: PlannerWeek.shift(monday, byWeeks: 0).addingTimeInterval(4 * 86_400))
        return start >= window.start && end <= window.end
    }

    private func updateModeHeader() {
        let height = modeHeader.setWeekMode(
            mode == .week,
            range: PlannerWeek.rangeLabel(monday: weekMonday),
            canGoBack: canShow(weekStarting: PlannerWeek.shift(weekMonday, byWeeks: -1)),
            canGoForward: canShow(weekStarting: PlannerWeek.shift(weekMonday, byWeeks: 1)))
        modeHeader.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: height)
        tableView.tableHeaderView = modeHeader   // reassigned so the table picks up the new height
    }

    private func rebuildWeek() {
        let today = PlannerItem.dayString(from: Date())
        weekSource.today = today
        weekSource.days = PlannerWeek.days(startingMonday: weekMonday, items: plannerItems, today: today) { [weak self] date in
            self?.weekDayInfo(for: date) ?? WeekDayInfo(weekdayName: "", classes: [], emptyMessage: nil)
        }
        tableView.reloadData()
    }

    /// What one day holds for this student, from the same resolver everything else uses. A class is
    /// listed once per letter, not at all if the student marked the block Free, and not on a weekday
    /// it does not meet: the same three rules the Tomorrow list applies.
    private func weekDayInfo(for date: Date) -> WeekDayInfo {
        let resolved = resolveDay(date: date)
        var classes = [WeekClass]()
        var seen = Set<String>()
        for scheduleBlock in resolved.blocks {
            let letter = scheduleBlock.block.uppercased()
            guard !seen.contains(letter),
                  let assignment = LoginVC.blocks[letter] as? String, assignment.contains("~") else { continue }
            let subject = assignment.getValues()[0]
            if ClassIdentity.isFree(subject) { continue }
            if resolved.weekdayIndex >= 0 && resolved.weekdayIndex <= 4,
               let meets = LoginVC.classMeetingDays[letter.lowercased()]?[resolved.weekdayIndex], !meets { continue }
            seen.insert(letter)
            classes.append(WeekClass(block: letter, subject: subject))
        }
        return WeekDayInfo(weekdayName: resolved.weekdayName, classes: classes,
                           emptyMessage: resolved.hasClasses ? nil : resolved.emptyMessage)
    }

    @objc private func pullToRefresh() {
        loadNextSchoolDay()
        loadPlanner()
    }

    private func presentPlannerEditor(for item: PlannerItem?) {
        let context = item.map { PlannerSteps.context(for: $0, in: plannerItems) } ?? .none
        let editor = PlannerItemEditorVC(existing: item, context: context)
        editor.onChange = { [weak self] in self?.loadPlanner() }
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    // The row changes straight away and the write follows. If the write fails the list is
    // reloaded from the server, which puts the row back, and the student is told.
    private func togglePlannerItem(id: String) {
        guard let index = plannerItems.firstIndex(where: { $0.id == id }) else { return }
        var item = plannerItems[index]
        item.completed.toggle()
        plannerItems[index] = item
        plannerItems = PlannerListing.ordered(plannerItems, today: PlannerItem.dayString(from: Date()))
        tableView.reloadData()
        // A finished item stops reminding, and an un-finished one starts again, straight away.
        if PlannerReminderScheduler.didSave(item) { setNotifications() }
        PlannerStore.shared.save(item) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed(error.message)
                    self?.loadPlanner()
                }
            }
        }
    }

    /// Asks first if the item has steps, since they go with it; otherwise deletes straight away, as before.
    private func requestDeletePlannerItem(id: String) {
        guard let item = plannerItems.first(where: { $0.id == id }) else { return }
        let steps = PlannerSteps.context(for: item, in: plannerItems).steps
        guard !steps.isEmpty else {
            deletePlannerItems(ids: [id])
            return
        }
        let alert = UIAlertController(title: PlannerSteps.deleteMessage(parentTitle: item.title, stepCount: steps.count),
                                      message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deletePlannerItems(ids: [id] + steps.map { $0.id })
        }))
        present(alert, animated: true)
    }

    private func deletePlannerItems(ids: [String]) {
        let gone = Set(ids)
        plannerItems.removeAll { gone.contains($0.id) }
        tableView.reloadData()
        updateEmptyState()
        var changed = false
        for id in ids where PlannerReminderScheduler.didDelete(id: id) { changed = true }
        if changed { setNotifications() }
        // One atomic write: a parent and its steps go together or not at all. On failure the list is
        // reloaded from the server, which puts them all back.
        PlannerStore.shared.deleteAll(ids: ids) { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed(error.message)
                    self?.loadPlanner()
                }
            }
        }
    }

    // Incomplete first (block order), completed ones dropped to the bottom and faded -
    // still there to reopen, just out of the way once they're done.
    private func applySortedEntries(_ built: [HomeworkEntry]) {
        entries = built.sorted { a, b in
            if a.completed != b.completed { return !a.completed }
            return a.block < b.block
        }
        tableView.reloadData()
    }

    private func toggleCompleted(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index].completed.toggle()
        persistEntries()
        applySortedEntries(entries)
    }

    private func presentHomeworkEntry(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let entry = entries[index]
        let alert = UIAlertController(title: entry.subject, message: "Homework for Block \(entry.block)", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = entry.text
            textField.placeholder = "What's due?"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self, self.entries.indices.contains(index) else { return }
            self.entries[index].text = alert.textFields?.first?.text ?? ""
            self.persistEntries()
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        }))
        present(alert, animated: true)
    }

    // Only entries with real content are worth keeping, and only this date's entries
    // are being replaced - other dates' history stays untouched.
    private func persistEntries() {
        guard !resolvedDateKey.isEmpty else { return }
        var stored = (LoginVC.blocks["classHomework"] as? [[String: Any]]) ?? []
        stored.removeAll { ($0["date"] as? String) == resolvedDateKey }
        for entry in entries where !entry.text.isEmpty || entry.completed {
            stored.append(["date": entry.date, "block": entry.block, "text": entry.text, "completed": entry.completed])
        }
        LoginVC.blocks["classHomework"] = stored
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else { return }
        Firestore.firestore().collection("users").document(uid).updateData(["classHomework": stored])
    }
}
