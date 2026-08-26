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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }
    // Repurposed from the old "add a task" flow (which no longer applies - there's
    // nothing to add, the list is the day's actual classes) into a manual refresh,
    // in case the app has been open across midnight and the "next school day" has
    // quietly become today.
    @IBAction func addClass(_ sender: UIBarButtonItem) {
        loadNextSchoolDay()
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        tableView.backgroundColor = UIColor(named: "background")
        return tableView
    } ()
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
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
        presentHomeworkEntry(at: indexPath.row)
    }

    private var entries = [HomeworkEntry]()
    private var resolvedDateKey = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "background")
        tableView.backgroundColor = UIColor(named: "background")
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        loadNextSchoolDay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Cheap and idempotent - re-running this if the tab is just being re-shown
        // the same day produces the same list, and catches a midnight rollover if
        // the app was left open.
        loadNextSchoolDay()
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
            tableView.setEmptyMessage("Couldn't find an upcoming school day with classes.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d" // same key format resolveDay itself uses
        resolvedDateKey = dateFormatter.string(from: resolved.date)

        let stored = (LoginVC.blocks["classHomework"] as? [[String: Any]]) ?? []

        var built = [HomeworkEntry]()
        for scheduleBlock in resolved.blocks {
            let letter = scheduleBlock.block.uppercased()
            let assignment = (LoginVC.blocks[letter] as? String) ?? ""
            // Only this student's own classes - not every block the school runs that day.
            guard assignment.contains("~") else { continue }
            let subject = assignment.getValues()[0]
            let existing = stored.first { ($0["block"] as? String) == letter && ($0["date"] as? String) == resolvedDateKey }
            built.append(HomeworkEntry(
                block: letter,
                subject: subject,
                date: resolvedDateKey,
                text: (existing?["text"] as? String) ?? "",
                completed: (existing?["completed"] as? Bool) ?? false
            ))
        }

        applySortedEntries(built)

        if entries.isEmpty {
            tableView.setEmptyMessage("No classes set up yet - add them in Settings.")
        } else {
            tableView.restore()
            tableView.separatorStyle = .none
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
