//
//  ScheduleScanVC.swift
//  BBNDaily
//
//  HQ-656: point a camera at a printed schedule instead of typing seven classes by hand.
//  Talks to /api/student/classes (HQ-656's backend half, PR #57) - that route never
//  writes anywhere, so nothing here is saved until the student reviews and confirms it,
//  same rule the admin schedule tool follows for the whole school's calendar.
//

import UIKit
import Firebase
import FirebaseAuth
import ProgressHUD

struct ScannedClass {
    var block: String
    var subject: String
    var teacher: String
    var room: String
}

/// A lunch wave read off the same photo: which weekday, which of the two waves, and the
/// lettered block that carries lunch that day.
///
/// Students have always set these five by hand in Settings, one per weekday, and they are
/// printed on the sheet being photographed ("Lunch-2nd", "Lunch-1st"). The weekday-to-block
/// pairing is not written down again here: `lunchBlockByWeekday()` derives it from
/// `regularSchedule`, so a year in which BB&N moves lunch moves this with it.
struct ScannedLunch {
    var weekday: String
    var block: String
    var wave: Int

    var displayName: String { "\(weekday.capitalized) lunch" }
    /// The exact strings Settings has always written, so a scanned value and a typed one are
    /// the same value and the schedule's `filter: ["L1"]` / `["L2"]` keeps matching.
    var storedValue: String { wave == 1 ? "1st Lunch" : "2nd Lunch" }
}

class ScheduleScanVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = UIColor(named: "current-cell")?.withAlphaComponent(0.1)
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        return iv
    }()
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "scanRow")
        return tv
    }()
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemGray
        label.text = "Tap a row to fix anything before saving. Nothing is saved yet."
        return label
    }()

    private var results = [ScannedClass]()
    private var lunchResults = [ScannedLunch]()

    /// Nothing was read, or the student removed every row. Either way there is nothing to save
    /// and no reason to keep them on a blank review screen.
    private var hasNothingToSave: Bool { results.isEmpty && lunchResults.isEmpty }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scan Your Schedule"
        view.backgroundColor = UIColor(named: "background")
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveAll))
        navigationItem.rightBarButtonItem?.isEnabled = false

        view.addSubview(imageView)
        view.addSubview(hintLabel)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 160),

            hintLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            hintLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            hintLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        promptForPhotoSource()
    }

    private func promptForPhotoSource() {
        let alert = UIAlertController(
            title: "Scan Your Schedule",
            message: "Take a photo or choose one from your library. Your classes won't be saved until you review and confirm them here.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { [weak self] _ in self?.presentPicker(source: .camera) }))
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { [weak self] _ in self?.presentPicker(source: .photoLibrary) }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            if self?.hasNothingToSave ?? true { self?.navigationController?.popViewController(animated: true) }
        }))
        present(alert, animated: true)
    }

    private func presentPicker(source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("That option isn't available on this device.")
            promptForPhotoSource()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: { [weak self] in
            if self?.hasNothingToSave ?? true { self?.promptForPhotoSource() }
        })
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = (info[.originalImage] as? UIImage) else { return }
        imageView.image = image
        scanImage(image)
    }

    /// The longest edge the photo is resized to before encoding.
    ///
    /// A full-resolution iPhone photo is around 4000x3000. At quality 0.7 that is roughly
    /// 3-5 MB, and base64 inflates it by a further third, so the request body lands near or
    /// past BOTH limits it has to clear: the route's own 6 MB cap on the encoded string, and
    /// Vercel's 4.5 MB serverless request-body limit, which rejects before any of this code's
    /// error handling is reached. The student would just see "check your connection".
    ///
    /// 2000px on the long edge keeps printed schedule text comfortably legible to the model
    /// while putting the encoded body around 1 MB, well inside both.
    private static let maxUploadEdge: CGFloat = 2000

    private func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > Self.maxUploadEdge else { return image }
        let scale = Self.maxUploadEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    private func scanImage(_ image: UIImage) {
        guard let data = downscaled(image).jpegData(compressionQuality: 0.7) else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("Couldn't read that photo. Try another one.")
            return
        }
        showLoader(text: "Reading your schedule...")
        Auth.auth().currentUser?.getIDToken(completion: { [weak self] token, error in
            guard let self = self else { return }
            guard let token = token, error == nil else {
                self.hideLoader(completion: {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Couldn't verify your sign-in. Try again.")
                })
                return
            }
            self.postScan(token: token, imageData: data)
        })
    }

    private func postScan(token: String, imageData: Data) {
        guard let url = URL(string: "https://mikeveson.com/knight-life/api/student/classes") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "attachments": [["mediaType": "image/jpeg", "data": imageData.base64EncodedString()]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideLoader(completion: {
                    self.handleScanResponse(data: data, error: error)
                })
            }
        }.resume()
    }

    private func handleScanResponse(data: Data?, error: Error?) {
        guard error == nil, let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("That scan failed. Check your connection and try again.")
            promptForPhotoSource()
            return
        }

        if let errorMessage = json["error"] as? String {
            let budgetExhausted = (json["budgetExhausted"] as? Bool) ?? false
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed(errorMessage)
            if budgetExhausted {
                // Out of scans for the year - the manual picker in Settings still works,
                // same message the backend sent.
                navigationController?.popViewController(animated: true)
            } else {
                promptForPhotoSource()
            }
            return
        }

        let rawClasses = (json["classes"] as? [[String: Any]]) ?? []
        results = rawClasses.compactMap { dict in
            guard let block = dict["block"] as? String, let subject = dict["subject"] as? String else { return nil }
            return ScannedClass(block: block, subject: subject, teacher: (dict["teacher"] as? String) ?? "", room: (dict["room"] as? String) ?? "")
        }

        // Lunch arrives keyed by weekday ("monday": 2). The lettered block that carries lunch
        // that day comes from the schedule rather than from the server, because the server has
        // no reason to know the app's block layout and the app already does.
        let rawLunch = (json["lunch"] as? [String: Any]) ?? [:]
        let blockForWeekday = lunchBlockByWeekday()
        lunchResults = lunchWeekdaysInOrder().compactMap { pair in
            guard let wave = (rawLunch[pair.weekday] as? NSNumber)?.intValue, wave == 1 || wave == 2 else { return nil }
            guard let block = blockForWeekday[pair.weekday] else { return nil }
            return ScannedLunch(weekday: pair.weekday, block: block, wave: wave)
        }

        guard !results.isEmpty || !lunchResults.isEmpty else {
            let message = (json["message"] as? String) ?? "Couldn't read any classes from that photo."
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed(message)
            promptForPhotoSource()
            return
        }

        updateSaveButton()
        tableView.reloadData()
    }

    // MARK: - Review list

    // Two sections, because a class and a lunch wave are edited differently: a class has
    // three free-text fields, a lunch wave has exactly two possible values.
    private enum Section: Int, CaseIterable { case classes, lunch }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .classes: return results.isEmpty ? nil : "Classes"
        case .lunch:   return lunchResults.isEmpty ? nil : "Lunch"
        default:       return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .classes: return results.count
        case .lunch:   return lunchResults.count
        default:       return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scanRow", for: indexPath)
        cell.backgroundColor = UIColor(named: "background")
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.detailTextLabel?.textColor = .systemGray
        cell.accessoryType = .disclosureIndicator

        switch Section(rawValue: indexPath.section) {
        case .lunch:
            let row = lunchResults[indexPath.row]
            cell.textLabel?.text = "\(row.displayName) (\(row.block) Block)"
            cell.detailTextLabel?.text = row.storedValue
        default:
            let row = results[indexPath.row]
            cell.textLabel?.text = "Block \(row.block.uppercased()): \(row.subject)"
            cell.detailTextLabel?.text = [row.teacher, row.room].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .lunch: editLunch(at: indexPath.row)
        default:     editRow(at: indexPath.row)
        }
    }

    private func editRow(at index: Int) {
        let row = results[index]
        let alert = UIAlertController(title: "Block \(row.block.uppercased())", message: "Fix anything that's wrong, or remove this class.", preferredStyle: .alert)
        alert.addTextField { field in field.text = row.subject; field.placeholder = "Subject" }
        alert.addTextField { field in field.text = row.teacher; field.placeholder = "Teacher" }
        alert.addTextField { field in field.text = row.room; field.placeholder = "Room" }
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            self.results.remove(at: index)
            self.tableView.reloadData()
            self.updateSaveButton()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.results[index].subject = alert.textFields?[0].text ?? row.subject
            self.results[index].teacher = alert.textFields?[1].text ?? row.teacher
            self.results[index].room = alert.textFields?[2].text ?? row.room
            self.tableView.reloadRows(at: [IndexPath(row: index, section: Section.classes.rawValue)], with: .fade)
        }))
        present(alert, animated: true)
    }

    /// A lunch wave has exactly two values, so this is a picker rather than a text field -
    /// there is no third thing a student could mean, and a typo here silently shows them the
    /// wrong half of every school day.
    private func editLunch(at index: Int) {
        let row = lunchResults[index]
        let alert = UIAlertController(
            title: row.displayName,
            message: "Which lunch do you have on \(row.weekday.capitalized)s? This is your \(row.block) block day.",
            preferredStyle: .actionSheet
        )
        for wave in [1, 2] {
            let title = wave == 1 ? "1st Lunch" : "2nd Lunch"
            let action = UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.lunchResults[index].wave = wave
                self.tableView.reloadRows(at: [IndexPath(row: index, section: Section.lunch.rawValue)], with: .fade)
            })
            if row.wave == wave { action.setValue(true, forKey: "checked") }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            self.lunchResults.remove(at: index)
            self.tableView.reloadData()
            self.updateSaveButton()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func updateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = !results.isEmpty || !lunchResults.isEmpty
    }

    // MARK: - Confirm and save

    @objc private func saveAll() {
        guard !results.isEmpty || !lunchResults.isEmpty else { return }
        showLoader(text: "Saving your classes...")
        saveNextClass(index: 0)
    }

    // One block at a time, same reasoning as resetClasses (HQ-649): each write is
    // self-contained, so a failure partway through leaves everything before it durably
    // saved rather than losing the whole batch.
    private func saveNextClass(index: Int) {
        guard index < results.count else {
            saveLunchPreferences()
            return
        }
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else {
            hideLoader(completion: {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.failed("Please sign out and back in to fix your account")
            })
            return
        }

        let row = results[index]
        // A blank teacher or room stays BLANK, exactly as AddClassVC does. "N/A" is a display
        // convention applied when a key is parsed (String.setNotAvailable), never stored.
        // Writing it here produced `Subject~N/A~N/A~A`, while ClassesOptionsPopupVC strips
        // "N/A" before looking a class up, so the document created and the document later
        // selected were two different keys.
        let classKey = "\(row.subject)~\(row.teacher)~\(row.room)~\(row.block.uppercased())"

        let db = Firestore.firestore()
        let classDoc = db.collection("classes").document(classKey)
        classDoc.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.abortSave(at: index, reason: error)
                return
            }
            var members = (snapshot?.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
            if !members.contains(where: { ($0["uid"] ?? "") == uid }) {
                members.append(["name": LoginVC.fullName, "email": LoginVC.email, "uid": uid])
            }
            // Every write is checked. Both completions used to be `{ _ in }`, so a refused or
            // failed write carried on to the next block and the screen still reported
            // "Classes saved" - the one outcome a student must never be told wrongly, because
            // they then stop and their schedule is silently not set.
            classDoc.setData(["members": members, "block": row.block.uppercased()], merge: true, completion: { error in
                if let error = error {
                    self.abortSave(at: index, reason: error)
                    return
                }
                db.collection("users").document(uid)
                    .setData([row.block.uppercased(): classKey], merge: true, completion: { error in
                        if let error = error {
                            self.abortSave(at: index, reason: error)
                            return
                        }
                        LoginVC.blocks[row.block.uppercased()] = classKey
                        self.saveNextClass(index: index + 1)
                    })
            })
        }
    }

    /// The five lunch waves, written in ONE merge rather than five, because unlike a class
    /// they touch no roster and nothing outside this document - so there is no partial state
    /// worth preserving, and one write means one chance to fail.
    ///
    /// `merge: true` on purpose. Settings writes this preference with
    /// `currDoc.setData(LoginVC.blocks)`, an unmerged write of the whole in-memory dictionary,
    /// which replaces the stored document with whatever the app happens to be holding. That is
    /// survivable there because Settings has just loaded the document; here the student may
    /// have been on this screen for a while, so only the keys being changed are sent.
    private func saveLunchPreferences() {
        guard !lunchResults.isEmpty else {
            finishSave()
            return
        }
        guard let uid = LoginVC.blocks["uid"] as? String, !uid.isEmpty else {
            hideLoader(completion: {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.failed("Please sign out and back in to fix your account")
            })
            return
        }

        var payload = [String: Any]()
        for lunch in lunchResults {
            payload[lunchPreferenceKey(forBlock: lunch.block)] = lunch.storedValue
        }

        Firestore.firestore().collection("users").document(uid).setData(payload, merge: true, completion: { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                // The classes are already saved at this point, so this says what did and did
                // not land rather than reporting the whole save as failed.
                print("schedule scan lunch save failed: \(error)")
                self.hideLoader(completion: {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Saved your classes, but not your lunches. Set those in Settings.")
                })
                return
            }
            // Only after the write lands, so the app never shows a preference the server
            // rejected.
            for (key, value) in payload { LoginVC.blocks[key] = value }
            self.finishSave()
        })
    }

    private func finishSave() {
        // Both halves of what this screen writes change what a reminder should say and when.
        // Classes change WHICH class a block reminder names; the lunch wave changes WHEN the
        // blocks around lunch start and end. Anything already scheduled is now describing the
        // schedule the student had before they scanned.
        //
        // setNotifications() clears the pending requests first and no-ops if notifications are
        // off, and it is also the only thing that fills LoginVC.upcomingDays, which CalendarVC
        // reads for "Next Day of Classes" (HQ-639). Skipping it would leave that list stale too.
        setNotifications()

        hideLoader(completion: { [weak self] in
            guard let self = self else { return }
            ProgressHUD.colorAnimation = .green
            ProgressHUD.succeed(self.lunchResults.isEmpty ? "Classes saved" : "Classes and lunches saved")
            self.navigationController?.popViewController(animated: true)
        })
    }

    /// Stops the chain and says how far it got. Blocks before `index` are already durably
    /// saved (each one commits before the next begins), so naming the count is accurate and
    /// re-running finishes the rest.
    private func abortSave(at index: Int, reason: Error) {
        print("schedule scan save failed at block \(index): \(reason)")
        hideLoader(completion: { [weak self] in
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed(index == 0
                ? "Couldn't save your classes. Try again."
                : "Saved \(index) of \(self?.results.count ?? 0) classes, then stopped. Try again to finish.")
        })
    }
}
