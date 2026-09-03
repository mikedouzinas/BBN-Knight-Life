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

    /// The DAY, and only the day.
    ///
    /// The row used to read `Mondays · D block` on the left and `2nd Lunch` on the right, which
    /// puts two answers on one line and makes the block letter look like the thing being set.
    /// Mike, twice: "it said lunch, like D-block, which I was confused about", then "isn't it
    /// first or second lunch that matters?" It is. The wave is the only value stored, so the wave
    /// is the only value on the row, and the block letter moved into the section footer where it
    /// is explained once instead of asserted five times.
    var displayName: String { "\(weekday.capitalized)s" }
    /// "Mondays (D block)" - for the edit sheet's title, where naming the block is genuinely
    /// useful because the student is being asked to check it against a specific row on the sheet.
    var displayNameWithBlock: String { "\(weekday.capitalized)s (\(block) block)" }
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
    /// The grade read off the sheet's header, shown for confirmation like everything else.
    /// The server detected this from the start and the app used to discard it silently, so a
    /// student confirmed their classes and their lunches and never saw the third thing that
    /// was about to be written to their record.
    private var gradeResult: String?

    /// Nothing was read, or the student removed every row. Either way there is nothing to save
    /// and no reason to keep them on a blank review screen.
    private var hasNothingToSave: Bool { results.isEmpty && lunchResults.isEmpty && gradeResult == nil }

    /// Closes this screen whichever way it was opened.
    ///
    /// Settings PUSHES it; the new-school-year prompt in AuthVC PRESENTS it as the root of its
    /// own navigation controller, because a launch-time prompt has no navigation stack to push
    /// onto. `popViewController` on a root does nothing at all, so a single pop would have left
    /// a student stuck on this screen with no way back - and that student is a new user in
    /// their first thirty seconds of the school year.
    @objc func closeSelf() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// Leaving with a reviewed-but-unsaved schedule on screen asks first.
    ///
    /// A scan costs the student one of five for the year, and this screen holds the whole result
    /// in memory only - walking away discards it and the next attempt spends another one. The
    /// screen says "Nothing is saved yet" to make the review trustworthy, and that same sentence
    /// is exactly why an accidental back is expensive.
    ///
    /// Wired to a REPLACEMENT left bar button rather than to `viewWillDisappear`, because by the
    /// time the view is disappearing the pop has already been committed and there is nothing left
    /// to confirm. The interactive swipe-back gesture is disabled for the same reason: it cannot
    /// be intercepted the way a button can, and a half-swipe that completes by accident is the
    /// most likely way this happens at all.
    @objc private func confirmDiscardAndClose() {
        guard !hasNothingToSave else {
            closeSelf()
            return
        }
        let alert = UIAlertController(
            title: "Don't Save Your Classes?",
            message: "You scanned your schedule but haven't saved it. Leaving now throws this away, and scanning again uses another of your scans for the year.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep Reviewing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save Now", style: .default, handler: { [weak self] _ in
            self?.saveAll()
        }))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive, handler: { [weak self] _ in
            self?.closeSelf()
        }))
        present(alert, animated: true)
    }

    /// Puts the confirm-on-leave control in place, whichever way this screen was opened.
    ///
    /// Pushed from Settings it needs to replace the system back button; presented from the
    /// new-school-year prompt there is no back button and it needs a Cancel. Both end up calling
    /// the same confirmation, so the guard cannot be present on one route and missing on the other
    /// - and the presented route is the one a brand-new student sees first.
    private func installLeaveButton() {
        let isPushed = navigationController.map { $0.viewControllers.first !== self } ?? false
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: isPushed ? "Back" : "Cancel",
            style: .plain,
            target: self,
            action: #selector(confirmDiscardAndClose)
        )
        navigationItem.hidesBackButton = true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scan Your Schedule"
        view.backgroundColor = UIColor(named: "background")
        tableView.backgroundColor = UIColor(named: "background")
        tableView.delegate = self
        tableView.dataSource = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveAll))
        navigationItem.rightBarButtonItem?.isEnabled = false
        installLeaveButton()

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

    /// Hands the swipe-back gesture back to the navigation controller.
    ///
    /// `installLeaveButton` disables it so an accidental swipe cannot discard an unsaved scan, and
    /// that recognizer belongs to the NAVIGATION CONTROLLER, not to this screen - leaving it off
    /// would kill swipe-back on every Settings screen for the rest of the session.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
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
            if self?.hasNothingToSave ?? true { self?.closeSelf() }
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

    /// The scan endpoint, on the CANONICAL host.
    ///
    /// `www.` is load-bearing and not a style choice. `mikeveson.com` answers with a 308 to
    /// `www.mikeveson.com`, and a redirect to a DIFFERENT HOST makes URLSession drop the
    /// `Authorization` header - that is the spec, not a bug, and every correct HTTP client
    /// does it. The server then sees a request with no token and answers "Sign in with Google
    /// first.", which is indistinguishable from being signed out. It cost a whole round of
    /// testing on 2026-09-03: the account was fine, the token was fine, and the header was
    /// being thrown away one hop before it arrived.
    ///
    /// Anything else this app posts to mikeveson.com has to use `www.` for the same reason.
    /// `scripts/check-app-urls.sh` fails the build if one does not.
    static let scanEndpoint = "https://www.mikeveson.com/knight-life/api/student/classes"

    private func postScan(token: String, imageData: Data) {
        guard let url = URL(string: Self.scanEndpoint) else { return }
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
                closeSelf()
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

        if let details = json["details"] as? [String: Any], let grade = details["grade"] as? String,
           ["9", "10", "11", "12"].contains(grade) {
            gradeResult = grade
        }

        remainingScans = (json["remainingScans"] as? NSNumber)?.intValue

        guard !hasNothingToSave else {
            reportNothingFound(modelMessage: json["message"] as? String)
            return
        }

        updateSaveButton()
        tableView.reloadData()
    }

    /// How many scans the student has left this year, as of the last response.
    private var remainingScans: Int?

    /// The photo produced nothing at all: not a schedule, too blurry, or the wrong page.
    ///
    /// An alert rather than `ProgressHUD.failed`, and this is the one place in this screen where
    /// that difference matters. The HUD shows one short line for a moment and then vanishes, which
    /// is fine for "Classes saved" and wrong here: the student has just SPENT one of five scans
    /// and needs to read why, decide whether another photo would do better, and know that typing
    /// it in by hand is still a complete option. Flashing the model's prose and immediately
    /// re-opening the camera invites them to spend a second scan on the same bad photo.
    private func reportNothingFound(modelMessage: String?) {
        // The model is told to say what went wrong in prose when it cannot read a sheet, so this
        // is usually specific ("this looks like a course catalogue, not a schedule"). The
        // fallback covers a response that carried no prose.
        let explanation = (modelMessage?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "Nothing on that photo looked like a class schedule."

        var message = explanation
        if let left = remainingScans {
            message += left == 0
                ? "\n\nThat was your last scan for this year. You can still set your classes by hand in Settings."
                : "\n\nYou have \(left) scan\(left == 1 ? "" : "s") left this year."
        }
        message += "\n\nA photo works best when the whole sheet is in frame, lying flat, in good light."

        let alert = UIAlertController(title: "Couldn't Read That Photo", message: message, preferredStyle: .alert)
        if remainingScans != 0 {
            alert.addAction(UIAlertAction(title: "Try Another Photo", style: .default, handler: { [weak self] _ in
                self?.promptForPhotoSource()
            }))
        }
        // Always available, and named as the equal option it is rather than as a consolation.
        alert.addAction(UIAlertAction(title: "Enter Classes by Hand", style: .default, handler: { [weak self] _ in
            self?.closeSelf()
        }))
        // Offered HERE because this is the highest-signal failure the feature has: a student is
        // looking at their own sheet, knows exactly what it says, and the scan just told them it
        // could read none of it. That is the report worth having in week one, and it is gone the
        // moment they close this alert and type their classes in by hand.
        alert.addAction(UIAlertAction(title: "Report a Problem", style: .default, handler: { [weak self] _ in
            self?.promptForFeedback(context: "schedule-scan-empty")
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.closeSelf()
        }))
        present(alert, animated: true)
    }

    /// The line under the photo, rewritten to describe what actually came back.
    ///
    /// The static "Tap a row to fix anything before saving" is right once there are rows, but it
    /// says nothing about how much of the sheet was read - and "it only found four classes" is the
    /// single most likely thing to read as a broken feature when it is in fact the prompt refusing
    /// to invent the other three.
    private func updateHint() {
        let courses = results.filter { !ClassIdentity.isFree($0.subject) }.count
        let frees = results.count - courses

        var parts = [String]()
        if courses > 0 { parts.append("\(courses) class\(courses == 1 ? "" : "es")") }
        if frees > 0 { parts.append("\(frees) free block\(frees == 1 ? "" : "s")") }
        if !lunchResults.isEmpty { parts.append("your lunches") }
        if gradeResult != nil { parts.append("your grade") }

        guard !parts.isEmpty else {
            hintLabel.text = "Tap a row to fix anything before saving. Nothing is saved yet."
            return
        }
        let found = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        hintLabel.text = "Read \(found). Tap any row to fix or remove it. Nothing is saved yet."
    }

    // MARK: - Review list

    // Two sections, because a class and a lunch wave are edited differently: a class has
    // three free-text fields, a lunch wave has exactly two possible values.
    private enum Section: Int, CaseIterable { case classes, lunch, grade }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .classes: return results.isEmpty ? nil : "Classes"
        case .lunch:   return lunchResults.isEmpty ? nil : "Which lunch you have"
        case .grade:   return gradeResult == nil ? nil : "Grade"
        default:       return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .classes: return results.count
        case .lunch:   return lunchResults.count
        case .grade:   return gradeResult == nil ? 0 : 1
        default:       return 0
        }
    }

    /// Every block letter the app expects a student to have.
    private static let allBlocks = ["A", "B", "C", "D", "E", "F", "G"]

    /// The letters this photo said nothing about.
    ///
    /// A partial read is the EXPECTED outcome, not a failure: the prompt deliberately leaves out
    /// a letter the sheet never mentions rather than guessing "Free" for it, because guessing
    /// there invents a fact. A photo of half a sheet, a trimester sheet, or a page that cuts off
    /// mid-table all land here legitimately. So this has to be reported as information, and the
    /// student has to be told the rest is still theirs to set - otherwise "it only found four of
    /// my classes" reads as the feature being broken.
    private var missingBlocks: [String] {
        let found = Set(results.map { $0.block.uppercased() })
        return Self.allBlocks.filter { !found.contains($0) }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .classes:
            guard !results.isEmpty else { return nil }
            let missing = missingBlocks
            guard !missing.isEmpty else { return nil }
            if missing.count == 1 {
                return "Block \(missing[0]) wasn't on this photo. Saving won't clear it - set it in Settings, or scan a photo that shows it."
            }
            let letters = missing.dropLast().joined(separator: ", ") + " and " + missing.last!
            return "Blocks \(letters) weren't on this photo. Saving won't clear them - set them in Settings, or scan a photo that shows them."
        case .lunch:
            guard !lunchResults.isEmpty else { return nil }
            // The block letters live here, once, as the explanation for why lunch is not simply
            // "one lunch". Naming them on every row made the letter look like the answer.
            let pairs = lunchResults.map { "\($0.weekday.prefix(3).capitalized) \($0.block)" }.joined(separator: ", ")
            return "Lunch falls in a different block each day (\(pairs)). All you're confirming is which of the two waves you're in."
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scanRow", for: indexPath)
        cell.backgroundColor = UIColor(named: "background")
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.detailTextLabel?.textColor = .systemGray
        cell.accessoryType = .disclosureIndicator

        switch Section(rawValue: indexPath.section) {
        case .grade:
            cell.textLabel?.text = "Grade"
            cell.detailTextLabel?.text = gradeResult
        case .lunch:
            let row = lunchResults[indexPath.row]
            cell.textLabel?.text = row.displayName
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
        case .grade: editGrade()
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
            // The summary line counts courses and free blocks separately, and editing a subject
            // to or from "Free" moves a row between those two counts.
            self.updateSaveButton()
        }))
        present(alert, animated: true)
    }

    /// A lunch wave has exactly two values, so this is a picker rather than a text field -
    /// there is no third thing a student could mean, and a typo here silently shows them the
    /// wrong half of every school day.
    private func editLunch(at index: Int) {
        let row = lunchResults[index]
        let alert = UIAlertController(
            title: row.displayNameWithBlock,
            message: "Which lunch do you have on \(row.weekday.capitalized)s? On the sheet this is the row marked \"Lunch\" in \(row.block) block.",
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

    /// Four values, so a picker rather than a text field - same reasoning as the lunch row.
    private func editGrade() {
        let alert = UIAlertController(title: "Grade", message: "Read from the top of your schedule.", preferredStyle: .actionSheet)
        for grade in ["9", "10", "11", "12"] {
            let action = UIAlertAction(title: "Grade \(grade)", style: .default, handler: { [weak self] _ in
                self?.gradeResult = grade
                self?.tableView.reloadData()
            })
            if gradeResult == grade { action.setValue(true, forKey: "checked") }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Don't Set My Grade", style: .destructive, handler: { [weak self] _ in
            self?.gradeResult = nil
            self?.tableView.reloadData()
            self?.updateSaveButton()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Everything on this screen that describes the CURRENT contents of the review list.
    ///
    /// One call rather than two, because the Save button and the summary line answer the same
    /// question ("what is about to be saved") and drifted apart the moment one of them was
    /// updated after a row was removed and the other was not.
    private func updateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = !hasNothingToSave
        updateHint()
    }

    // MARK: - Confirm and save

    @objc private func saveAll() {
        guard !hasNothingToSave else { return }
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
        //
        // Canonical, so that two students scanning the same class compute the SAME key and
        // therefore write to the same document. See ClassIdentity for why that is also what
        // makes fifty simultaneous scans safe.
        let canonicalKey = ClassIdentity.canonicalClassKey(
            subject: row.subject, teacher: row.teacher, room: row.room, block: row.block)

        // Look for the class before making one. A canonical key agrees with other SCANS; it
        // cannot agree with a document typed by hand last year, which is not in canonical
        // form. This is the half that finds those.
        let db = Firestore.firestore()
        db.collection("classes")
            .whereField("block", isEqualTo: row.block.uppercased())
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                // A failed search is not a failed save. Fall back to the canonical key, which
                // is still correct - it just might create a document that a match would have
                // found. Better than stopping the student's setup on a flaky read.
                if let error = error {
                    print("schedule scan: class lookup failed for block \(row.block), using canonical key: \(error)")
                }
                let existing = snapshot?.documents.map({ $0.documentID }).first(where: {
                    ClassIdentity.matchesExistingClass(
                        existingKey: $0, subject: row.subject, teacher: row.teacher, block: row.block)
                })
                self.joinClass(key: existing ?? canonicalKey, row: row, index: index, uid: uid)
            }
    }

    /// Adds this student to one class document and points their block at it.
    private func joinClass(key classKey: String, row: ScannedClass, index: Int, uid: String) {
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
                // A free block's roster is everyone in the school with that block open, so it
                // is a much larger audience than a class of fifteen. Name and uid are what
                // "who else is free" needs; the email is not, and ClassPopupVC renders it
                // straight onto the row. Course rosters are unchanged.
                if ClassIdentity.isFree(row.subject) {
                    members.append(["name": LoginVC.fullName, "uid": uid])
                } else {
                    members.append(["name": LoginVC.fullName, "email": LoginVC.email, "uid": uid])
                }
            }
            // The FULL class document, the same shape AddClassVC writes.
            //
            // This used to send only `members` and `block`, and the missing field that mattered
            // was `name`. ClassesOptionsPopupVC builds every row of the block picker from
            // `document.data()["name"]` and nothing else - so a class created by a scan had no
            // name, `"".getValues()` returned ["N/A", "N/A", "N/A", ""], and the class the
            // student had just saved appeared in their own picker as "N/A". Two scanned classes
            // in one block were two rows both reading "N/A", which is indistinguishable from a
            // duplicate.
            //
            // `owner` matters for the same reason one step later: ClassPopupVC reads it with an
            // `?? "N/A"` fallback and shows it as who made the class.
            //
            let isNewClass = snapshot?.exists != true
            var payload: [String: Any] = ["members": members, "block": row.block.uppercased()]

            // Repaired even on an existing document, because a document with no name is exactly
            // what an earlier version of this screen created and those are already in the
            // database. Every other field below is create-only; this one is a fix-up.
            if (snapshot?.data()?["name"] as? String).map({ $0.isEmpty }) ?? true {
                payload["name"] = classKey
            }

            if isNewClass {
                // Create-only, all of it. Merging any of this into a class that already exists
                // would overwrite decisions somebody else made: `owner` would hand a teacher's
                // class to whichever student scanned it most recently, and the weekday flags
                // would switch a class back on for a day its owner had deliberately turned off.
                //
                // The flags are written explicitly on create even though every reader defaults a
                // missing flag to `true`, because "meets every weekday" is a claim about the
                // class, and leaning on a reader's fallback means the document is only correct
                // for as long as every future reader picks the same one.
                payload["owner"] = LoginVC.email
                for day in ["monday", "tuesday", "wednesday", "thursday", "friday"] {
                    payload[day] = true
                }
            }

            // Every write is checked. Both completions used to be `{ _ in }`, so a refused or
            // failed write carried on to the next block and the screen still reported
            // "Classes saved" - the one outcome a student must never be told wrongly, because
            // they then stop and their schedule is silently not set.
            classDoc.setData(payload, merge: true, completion: { error in
                if let error = error {
                    self.abortSave(at: index, reason: error)
                    return
                }
                // The class this block pointed at BEFORE the scan, if it pointed at a different
                // one. Read before the write below overwrites it.
                let previousKey = LoginVC.blocks[row.block.uppercased()] as? String

                db.collection("users").document(uid)
                    .setData([row.block.uppercased(): classKey], merge: true, completion: { error in
                        if let error = error {
                            self.abortSave(at: index, reason: error)
                            return
                        }
                        LoginVC.blocks[row.block.uppercased()] = classKey
                        // Leaving the old class is cleanup, not part of the save. It runs after
                        // the student's own record is already correct, so a failure here cannot
                        // cost them their schedule - it only leaves them on a roster they are
                        // no longer in, which is the lesser of the two wrongs.
                        self.leavePreviousClass(previousKey: previousKey, newKey: classKey, uid: uid)
                        self.saveNextClass(index: index + 1)
                    })
            })
        }
    }

    /// Takes the student off the roster of the class this block used to point at.
    ///
    /// Rescanning, or scanning over classes set by hand, re-points a block at a different class.
    /// Without this, the student's own record is correct and they are STILL a member of the old
    /// class - so they show up in ClassPopupVC for a class they are not in, and that class's
    /// roster count is wrong forever, because nothing else ever revisits it.
    ///
    /// It is the same failure HQ-649 fixed for "Clear My Classes", which AuthVC records as
    /// leaving "374 class documents carrying stale membership". Pointing a block somewhere new
    /// is the other way to cause it.
    ///
    /// Does nothing when the block is unchanged, when it was empty, or when both keys resolve to
    /// the same class - a student re-scanning the same schedule must not be removed from the
    /// class they just joined.
    private func leavePreviousClass(previousKey: String?, newKey: String, uid: String) {
        guard let previousKey = previousKey,
              !previousKey.isEmpty,
              previousKey.contains("~"),
              previousKey != newKey else { return }

        let classDoc = Firestore.firestore().collection("classes").document(previousKey)
        classDoc.getDocument { snapshot, error in
            guard error == nil, let data = snapshot?.data() else {
                print("schedule scan: could not read \(previousKey) to leave it: \(error?.localizedDescription ?? "missing")")
                return
            }
            var members = (data["members"] as? [[String: String]]) ?? [[String: String]]()
            let before = members.count
            members.removeAll { ($0["uid"] ?? "") == uid }
            guard members.count != before else { return }  // was not on it anyway

            classDoc.setData(["members": members], merge: true) { error in
                if let error = error {
                    // Reported, not surfaced: the student's schedule is already saved correctly
                    // and telling them their classes failed would be wrong.
                    print("schedule scan: left \(previousKey) but the write failed: \(error)")
                }
            }
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
        guard !lunchResults.isEmpty || gradeResult != nil else {
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
        // Same merge write as the lunch waves - it is the same document and the same kind of
        // preference, so there is no reason to spend a second round trip on it.
        if let grade = gradeResult { payload["grade"] = grade }

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
            self.closeSelf()
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
