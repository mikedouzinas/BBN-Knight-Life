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

    /// The weekdays this course actually meets, or nil for "the sheet did not say".
    ///
    /// HQ-922's first half. Most BB&N courses do not meet all five days - an arts course prints
    /// on two weekdays and the same letter prints "Unscheduled" on the other three - and until
    /// now every scanned class was created meeting every day.
    ///
    /// NIL IS NOT AN EMPTY WEEK. Nil means "not read" and leaves all five days on, which is what
    /// the app did before this existed. The distinction is the whole safety of the field: a
    /// class shown on a day it does not meet is a visible annoyance, while a class hidden on a
    /// day it does meet makes the student miss it with nothing on screen to say so.
    var days: [String]?

    static let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday"]

    /// What `days` reads as on the review screen. Empty when every day meets, because a class
    /// that meets all week is the unremarkable case and does not need saying.
    var meetingDaysSummary: String {
        guard let days = days, !days.isEmpty, days.count < ScannedClass.weekdays.count else { return "" }
        let short = ["monday": "Mon", "tuesday": "Tue", "wednesday": "Wed", "thursday": "Thu", "friday": "Fri"]
        return ScannedClass.weekdays.filter { days.contains($0) }.compactMap { short[$0] }.joined(separator: ", ")
    }
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
    /// 1 or 2, and after a scan it is never nil.
    ///
    /// Two decisions ended up here, in this order:
    ///
    /// A row exists for every weekday that carries a lunch choice, even one the photo said nothing
    /// about. These used to be `compactMap`ed away, so a weekday the model missed simply was not
    /// on the screen - Friday vanished off a real sheet, with no way to tell whether the sheet
    /// lacked the row, the model missed it, or the app dropped it, and no way to set it from here.
    ///
    /// And every one of those rows gets a value. Blank is not the cautious choice it looks like:
    /// the wave decides when the blocks either side of lunch start and end, so a day with no value
    /// makes that day's schedule wrong for a student who never opens Settings. Unanswered days
    /// default to 2nd and the footer names them and asks the student to check.
    ///
    /// The type stays optional because it is nil for the moment between the rows being built and
    /// the defaults being applied, and because "the photo did not say" is what
    /// `lunchDaysDefaulted` is computed from.
    var wave: Int?

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
    ///
    /// nil only before the defaults are applied. Nothing is ever written for a nil wave: the save
    /// path takes `answeredLunches`, so a row that somehow reached the screen without a value is
    /// skipped rather than guessed at that late stage.
    var storedValue: String? {
        guard let wave = wave else { return nil }
        return wave == 1 ? "1st Lunch" : "2nd Lunch"
    }

    /// What the row shows on the right. "Not set" should be unreachable after a scan, and is kept
    /// as an honest fallback rather than a crash if it ever is not.
    var displayValue: String { storedValue ?? "Not set" }
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
    /// Grouped, and NOT `.plain`.
    ///
    /// Two reasons, both of which were bugs on a device:
    ///
    /// 1. A plain table TRUNCATES a section footer to one line. Both footers here carry the
    ///    sentence that makes the section make sense - which blocks were missing from the photo,
    ///    and why lunch is a different block each day - and Mike saw the second one cut off
    ///    mid-word. A grouped table wraps them.
    /// 2. It is what Settings already uses, so the review list looks like the screen it was
    ///    reached from rather than like a different app.
    ///
    /// No `register(UITableViewCell.self, ...)`. Registering the CLASS makes `.default`-style
    /// cells, and a `.default` cell has a nil `detailTextLabel` - so every right-hand value on
    /// this screen was assigned to nothing and never drew. That silently hid the lunch wave, the
    /// grade, and every teacher and room. Cells are made by hand below in `.value1`, which is
    /// the style with a right-aligned grey detail label.
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
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

    /// The lunch rows that actually carry an answer.
    ///
    /// `lunchResults` now always holds all five weekdays, including unanswered ones, so it is no
    /// longer a count of what was read. Anything asking "did the scan produce anything" or "what
    /// gets written" has to use this instead, or an empty scan looks like a full one.
    private var answeredLunches: [ScannedLunch] { lunchResults.filter { $0.wave != nil } }

    /// Nothing was read, or the student removed every row. Either way there is nothing to save
    /// and no reason to keep them on a blank review screen.
    private var hasNothingToSave: Bool { results.isEmpty && answeredLunches.isEmpty && gradeResult == nil }

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
        view.addSubview(tableView)

        // The photo preview is a SHARE of the screen, not a fixed 160 points.
        //
        // 160pt is a fifth of an iPhone 17 Pro and better than a quarter of an SE - and the SE is
        // also the phone with the least room for the list underneath, so the fixed height took the
        // most space exactly where there was least of it. The photo is context; the seven rows
        // being confirmed are the content.
        //
        // The proportional one is `.defaultHigh` and the cap is required, which is what makes the
        // pair safe rather than contradictory: on a tall phone 22% exceeds 170, so the cap wins and
        // the proportional constraint yields instead of raising a conflict. On an SE 22% is about
        // 125, comfortably under the cap, so it holds. Two required constraints here would break
        // layout on every large phone.
        let imageHeight = imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.22)
        imageHeight.priority = .defaultHigh
        let imageHeightCap = imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 170)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),

            // Height is set below, as a share of the screen rather than a fixed 160pt.
            imageHeight,
            imageHeightCap,

            // Straight to the image. The hint label is the TABLE's header view now, not a sibling
            // above it, so nothing between the two moves when its text changes.
            tableView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        installHintAsTableHeader()
    }

    /// True once the photo prompt has been shown, so returning to this screen does not re-ask.
    private var hasPromptedForPhoto = false

    /// The photo prompt is presented from `viewDidAppear`, not `viewDidLoad`.
    ///
    /// A view controller's view is not in the window hierarchy during `viewDidLoad`, so presenting
    /// there is presenting from a controller that is not on screen yet - UIKit warns about exactly
    /// this, and it also makes the screen impossible to instantiate in a test without an alert
    /// trying to appear over nothing.
    ///
    /// The flag matters because `viewDidAppear` fires again every time the image picker is
    /// dismissed, and without it choosing a photo would immediately re-ask which photo to choose.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPromptedForPhoto else { return }
        hasPromptedForPhoto = true
        promptForPhotoSource()
    }

    /// Puts the summary line INSIDE the table, as its header view.
    ///
    /// It used to be a sibling view above the table, with the table's top pinned to the label's
    /// bottom. The label is multi-line, so every time the summary text changed length the label's
    /// intrinsic height changed, which moved the table's frame - and `reloadData()` had already
    /// laid the cells out against the old frame. The result on a device was rows that were partly
    /// missing and then snapped back the moment the screen was touched, because a touch forces the
    /// layout pass that had not happened yet.
    ///
    /// As a header view the table owns the label's geometry: changing the text re-measures the
    /// header and the rows follow, in one pass. That removes the class of bug rather than adding a
    /// `layoutIfNeeded()` to the places that happened to trigger it.
    private func installHintAsTableHeader() {
        let container = UIView()
        container.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            hintLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            hintLabel.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 20),
            hintLabel.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -20),
        ])
        tableView.tableHeaderView = container
        sizeTableHeader()
    }

    /// Re-measures the header to fit its text.
    ///
    /// A `tableHeaderView` is laid out by frame, not by constraints, so it does not resize itself
    /// when its content changes. Without this the header keeps the height it was first given and
    /// a longer summary is clipped.
    private func sizeTableHeader() {
        guard let header = tableView.tableHeaderView, tableView.bounds.width > 0 else { return }
        header.frame.size.width = tableView.bounds.width
        let height = header.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel).height
        guard abs(header.frame.height - height) > 0.5 else { return }
        header.frame.size.height = height
        // Reassigning is what makes the table pick the new height up, and it is also a full
        // re-layout of the table - which is why it must never happen while rows are animating.
        //
        // This is what was still making rows vanish and come back after tapping one to edit it.
        // The tap ran `reloadRows(with: .none)` and then `updateSaveButton()`, which rewrites the
        // summary line, which changes the header's height, which reassigned the header MID-FADE.
        // The table threw away the layout it was animating and did not rebuild it until the next
        // touch. Moving the label into the header fixed the version of this that happened on the
        // first load; this is the version that happens on every edit.
        //
        // `performWithoutAnimation` makes the re-layout atomic instead of interleaving with the
        // row animation, so the table ends in a laid-out state either way.
        UIView.performWithoutAnimation {
            tableView.tableHeaderView = header
            tableView.layoutIfNeeded()
        }
    }

    /// The header's width comes from the table's bounds, which are not final until the first
    /// layout pass and change again on rotation.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeTableHeader()
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

        // A spinner while the picker gets itself up.
        //
        // `UIImagePickerController` is slow to appear - it asks for photo-library permission, then
        // builds a whole browser over the user's library, and on a big library that is a visible
        // pause. Between the tap and the picker there was NOTHING on screen, so it read as a tap
        // that did not register. Mike: "sometimes there's a little delay between clicking 'choose
        // a photo' and when it actually pops up so the user is left confused."
        //
        // `interaction: false` blocks a second tap during the gap, which would otherwise queue a
        // second picker presentation behind the first.
        showLoader(text: source == .camera ? "Opening camera..." : "Opening photos...")

        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self

        // Constructing the picker is the slow part and it happens above, on the main thread; the
        // loader is torn down in the presentation's own completion so it covers the whole gap
        // rather than a guessed interval.
        present(picker, animated: true) { [weak self] in
            self?.hideLoader(completion: nil)
        }
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
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]

        guard error == nil, let json = json else {
            // A blocking alert, not a HUD. See `reportFailure` - a HUD that fades while the screen
            // is closing is a message nobody ever reads.
            reportFailure(
                title: "That Scan Didn't Work",
                message: "Couldn't reach the server. Check your connection and try again.",
                offerRetry: true)
            return
        }

        if let errorMessage = json["error"] as? String {
            let budgetExhausted = (json["budgetExhausted"] as? Bool) ?? false
            reportFailure(
                title: budgetExhausted ? "No Scans Left" : "That Scan Didn't Work",
                message: errorMessage,
                offerRetry: !budgetExhausted)
            return
        }

        let rawClasses = (json["classes"] as? [[String: Any]]) ?? []
        results = rawClasses.compactMap { dict in
            guard let block = dict["block"] as? String, let subject = dict["subject"] as? String else { return nil }
            // An unrecognised weekday is dropped rather than stored. If that empties the list,
            // it becomes nil - "not read" - never an empty week. See ScannedClass.days.
            let parsedDays = (dict["days"] as? [String])?
                .map { $0.lowercased() }
                .filter { ScannedClass.weekdays.contains($0) }
            return ScannedClass(
                block: block,
                subject: subject,
                teacher: (dict["teacher"] as? String) ?? "",
                room: (dict["room"] as? String) ?? "",
                days: (parsedDays?.isEmpty ?? true) ? nil : parsedDays)
        }

        if let details = json["details"] as? [String: Any], let grade = details["grade"] as? String,
           ["9", "10", "11", "12"].contains(grade) {
            gradeResult = grade
        }

        remainingScans = (json["remainingScans"] as? NSNumber)?.intValue

        // Lunch arrives keyed by weekday ("monday": 2). The lettered block that carries lunch that
        // day comes from the schedule rather than from the server, because the server has no reason
        // to know the app's block layout and the app already does.
        let rawLunch = (json["lunch"] as? [String: Any]) ?? [:]
        let wavesFromPhoto: [String: Int] = lunchWeekdaysInOrder().reduce(into: [:]) { out, pair in
            if let w = (rawLunch[pair.weekday] as? NSNumber)?.intValue, w == 1 || w == 2 { out[pair.weekday] = w }
        }

        // "Did this photo produce anything at all" is asked BEFORE lunch defaults are filled in,
        // and that ordering is load-bearing. Every lunch day gets a value below, so asking
        // afterwards would find five lunch rows on a photo of a wall and call it a successful scan.
        guard !results.isEmpty || !wavesFromPhoto.isEmpty || gradeResult != nil else {
            reportNothingFound(modelMessage: json["message"] as? String)
            return
        }

        // EVERY lunch weekday gets a wave, defaulting to 2nd for any the photo did not state.
        //
        // Leaving one blank is not the safe option, which is what it looked like when the choice
        // was "don't guess". The lunch wave decides when the blocks around lunch start and end, so
        // a day with no value does not degrade gracefully - the schedule for that day is wrong for
        // everyone, including the students who never open Settings. Mike: "if nothing is set the
        // app won't work schedule-wise... we will show one by default so don't let them save
        // without doing that."
        //
        // 2nd is the default because it is already the app's: SettingsBlockTableViewCell has shown
        // "2nd Lunch" for an unset lunch preference since long before this screen existed, so a
        // student who never touches either screen sees the same thing from both.
        //
        // A default is a claim, so the footer says so and asks them to check it against the sheet.
        lunchResults = lunchWeekdaysInOrder().map { pair in
            ScannedLunch(weekday: pair.weekday, block: pair.block, wave: wavesFromPhoto[pair.weekday] ?? 2)
        }
        lunchDaysDefaulted = lunchWeekdaysInOrder().filter { wavesFromPhoto[$0.weekday] == nil }.map { $0.weekday }

        hasScanned = true
        updateSaveButton()
        tableView.reloadData()
    }

    /// True once a scan has come back with something. Nothing is listed before that.
    ///
    /// Every section used to render from the moment the screen opened, so the Grade row sat there
    /// saying "Not set" while the camera was still being chosen - a value offered for confirmation
    /// before anything had been read. Sections are a report on a scan, so there is nothing to
    /// report until there has been one.
    private var hasScanned = false

    /// The weekdays whose lunch wave is a default rather than something read off the photo.
    /// Named so the footer can say which ones actually need checking.
    private var lunchDaysDefaulted = [String]()

    /// How many scans the student has left this year, as of the last response.
    private var remainingScans: Int?

    /// Says why a scan failed, and waits to be dismissed.
    ///
    /// Every failure here used to be a `ProgressHUD.failed(...)` followed immediately by either
    /// `closeSelf()` or a new photo prompt. A HUD fades out on its own after a moment, and popping
    /// the view controller takes it down early - so on a device the student saw a red something
    /// flash for a fraction of a second and then found themselves back in Settings with no idea
    /// what had happened. Mike, on scanning a photo that was not a schedule: "it just exited me to
    /// the settings page, didn't say anything, it seems to flash an error page but it disappears
    /// because we automatically go back."
    ///
    /// That is the worst possible outcome for the two failures a student will actually meet: an
    /// unreadable photo, which they can fix, and no scans left, where the message is the ONLY
    /// thing that tells them their classes can still be set by hand.
    ///
    /// - Parameter offerRetry: whether another photo is worth offering. False when the budget is
    ///   gone, because there is nothing left to spend on a retry.
    private func reportFailure(title: String, message: String, offerRetry: Bool) {
        var body = message
        if let left = remainingScans, offerRetry {
            body += "\n\nYou have \(left) scan\(left == 1 ? "" : "s") left this year."
        }
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        if offerRetry {
            alert.addAction(UIAlertAction(title: "Try Another Photo", style: .default, handler: { [weak self] _ in
                self?.promptForPhotoSource()
            }))
        }
        alert.addAction(UIAlertAction(title: "Enter Classes by Hand", style: .default, handler: { [weak self] _ in
            self?.closeSelf()
        }))
        alert.addAction(UIAlertAction(title: "Report a Problem", style: .default, handler: { [weak self] _ in
            self?.promptForFeedback(context: "schedule-scan-failed")
        }))
        present(alert, animated: true)
    }

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

        // Short on purpose. This was three paragraphs - the model's prose, a scan count, and
        // photography advice - and Mike read the result as "a BUNCH of text". An alert nobody
        // finishes reading is the same failure as the HUD that vanished before it could be read,
        // arriving from the other direction. The model's own sentence is the part that says
        // something specific about THIS photo, so it is the part that stays; the framing advice
        // is one short line, and the scan count only appears when it is nearly out, which is the
        // only time the number changes what the student should do.
        var message = explanation
        if let left = remainingScans, left <= 1 {
            message += left == 0
                ? "\n\nThat was your last scan this year. You can still set classes by hand."
                : "\n\n1 scan left this year."
        }
        message += "\n\nWorks best with the whole sheet flat and in frame."

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
        if !answeredLunches.isEmpty { parts.append("your lunches") }
        if gradeResult != nil { parts.append("your grade") }

        guard !parts.isEmpty else {
            hintLabel.text = "Tap a row to fix anything before saving. Nothing is saved yet."
            sizeTableHeader()
            return
        }
        let found = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        hintLabel.text = "Read \(found). Tap any row to fix or remove it. Nothing is saved yet."
        // The header is laid out by frame, so a text change needs an explicit re-measure.
        sizeTableHeader()
    }

    // MARK: - Review list

    /// One row of the review list.
    ///
    /// A named factory rather than an inline initialiser, purely so a test can assert the thing
    /// that broke: this screen used `register(UITableViewCell.self, ...)`, which makes cells in
    /// `.default` style, and a `.default` cell's `detailTextLabel` is **nil**. Every right-hand
    /// value here - the lunch wave, the grade, every teacher and room - was assigned to a nil
    /// label and silently never drew. The screen looked plausible and was missing every value on
    /// it, which is why it survived a build, a test run, a string check in the binary, and a
    /// device install, and was found by a person reading the screen.
    ///
    /// `ScheduleScanVCTests.testReviewCellCanShowARightHandValue` fails if this returns a style
    /// with no detail label. That is a cheap test for a class of bug that is invisible to every
    /// other check in this repository.
    static func makeReviewCell() -> UITableViewCell {
        UITableViewCell(style: .value1, reuseIdentifier: "scanRow")
    }

    // Two sections, because a class and a lunch wave are edited differently: a class has
    // three free-text fields, a lunch wave has exactly two possible values.
    private enum Section: Int, CaseIterable { case classes, lunch, grade }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Nothing at all until a scan has come back. Every section is a report ON a scan, and the
        // Grade row in particular sat there reading "Not set" while the camera was still being
        // chosen, offering a value for confirmation before anything had been read.
        guard hasScanned else { return nil }
        switch Section(rawValue: section) {
        case .classes: return results.isEmpty ? nil : "Classes"
        case .lunch:   return lunchResults.isEmpty ? nil : "Which lunch you have"
        case .grade:   return "Grade"
        default:       return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard hasScanned else { return 0 }
        switch Section(rawValue: section) {
        case .classes: return results.count
        case .lunch:   return lunchResults.count
        case .grade:   return 1
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
        guard hasScanned else { return nil }
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
            // No block letters, and nothing about how the school's schedule is arranged.
            //
            // This used to read "Lunch falls in a different block each day (Mon D, Tue C, ...)",
            // which is a claim about BB&N's timetable that this screen has no business making and
            // that stops being true the year they rearrange it. Mike: "that may change. make it
            // more simple." What the student is being asked is the same every year and does not
            // depend on the timetable at all.
            var text = "Some students have 1st lunch and some have 2nd, and it changes when your classes are that day. Check your schedule and set each day to match."
            if !lunchDaysDefaulted.isEmpty {
                // Naming the guessed days is the point. A default that looks identical to a
                // reading is a wrong answer nobody has any reason to check.
                let days = lunchDaysDefaulted.map { $0.capitalized }
                let list = days.count == 1 ? days[0] : days.dropLast().joined(separator: ", ") + " and " + days.last!
                text += "\n\nYour photo didn't say for \(list), so \(days.count == 1 ? "it is" : "they are") set to 2nd Lunch. Check \(days.count == 1 ? "it" : "them")."
            }
            return text
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scanRow") ?? Self.makeReviewCell()
        cell.backgroundColor = UIColor(named: "background")
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.detailTextLabel?.textColor = .systemGray
        cell.accessoryType = .disclosureIndicator

        switch Section(rawValue: indexPath.section) {
        case .grade:
            cell.textLabel?.text = "Grade"
            cell.detailTextLabel?.text = gradeResult.map { "Grade \($0)" } ?? "Not set"
        case .lunch:
            let row = lunchResults[indexPath.row]
            cell.textLabel?.text = row.displayName
            cell.detailTextLabel?.text = row.displayValue
        default:
            let row = results[indexPath.row]
            cell.textLabel?.text = "Block \(row.block.uppercased()): \(row.subject)"
            // The meeting days join the teacher and room rather than getting a row of their own:
            // a class that meets all week says nothing here, so the line only grows for the
            // classes where it is news. The student cannot edit it (HQ-922 owns that), but a
            // misread has to be visible rather than silently deciding their calendar.
            cell.detailTextLabel?.text = [row.teacher, row.room, row.meetingDaysSummary]
                .filter { !$0.isEmpty }
                .joined(separator: " \u{00B7} ")
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
            self.tableView.reloadRows(at: [IndexPath(row: index, section: Section.classes.rawValue)], with: .none)
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
                self.tableView.reloadRows(at: [IndexPath(row: index, section: Section.lunch.rawValue)], with: .none)
                // The Save button and the summary line both count answered days, and this is the
                // action that turns an unanswered day into an answered one.
                self.updateSaveButton()
            })
            if row.wave == wave { action.setValue(true, forKey: "checked") }
            alert.addAction(action)
        }
        // No "leave this unset" action, deliberately. Every lunch day must end up 1st or 2nd:
        // the wave decides when the blocks around lunch start and end, so a day with no value
        // makes that day's schedule wrong rather than merely incomplete. The only two answers a
        // student can give are the only two actions here.
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
                        existingKey: $0, subject: row.subject, teacher: row.teacher,
                        block: row.block, room: row.room)
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
            // `owner` is the one field deliberately left off - see the note where the weekday
            // flags are written. ClassPopupVC shows it with an `?? "N/A"` fallback as who made
            // the class, and "N/A" is the honest answer for a class nobody claimed.
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
                //
                // HQ-922: those flags used to be five hardcoded `true`s, which said every
                // scanned class meets every day. Most BB&N courses do not - an arts course
                // prints on two weekdays and the same letter reads "Unscheduled" on the other
                // three - and this is the field the calendar has always honoured, so writing it
                // correctly needs nothing else to change. `classMeetingDays` is read from here
                // in AuthVC, and nine places consume it.
                //
                // `row.days == nil` means the sheet did not say, NOT that the class never meets,
                // so it falls back to all five. A class shown on a day it does not meet is a
                // visible annoyance; one hidden on a day it does meet makes the student miss it.
                // `owner` is deliberately NOT set, and that is a change made the same day as the
                // weekday flags above, because those flags are what made it matter.
                //
                // DaySelectVC refuses an edit unless you are the class's owner or an admin, and
                // joinClass used to name whoever scanned first. That was survivable while every
                // scanned class met every day: there was nothing worth editing. Now the first
                // scanner's reading of the weekday columns decides twenty-four other students'
                // calendars, and every one of them gets "Sorry, you do not have permission to
                // edit this class" when they try to correct it.
                //
                // DaySelectVC already treats a missing owner as owned by nobody and never
                // denies on it, and firestore.rules does not read the field, so leaving it off
                // makes a scan-created class editable by everyone in it. A class created by
                // photographing a timetable is not owned by the student who photographed it -
                // which is HQ-923's point, arrived at from the other direction.
                for day in ScannedClass.weekdays {
                    payload[day] = row.days.map { $0.contains(day) } ?? true
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
        guard !answeredLunches.isEmpty || gradeResult != nil else {
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
        for lunch in answeredLunches {
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
            ProgressHUD.succeed(self.answeredLunches.isEmpty ? "Classes saved" : "Classes and lunches saved")
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
