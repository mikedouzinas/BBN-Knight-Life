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
        label.text = "Tap a class to fix anything before saving. Nothing is saved yet."
        return label
    }()

    private var results = [ScannedClass]()

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
            if self?.results.isEmpty ?? true { self?.navigationController?.popViewController(animated: true) }
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
            if self?.results.isEmpty ?? true { self?.promptForPhotoSource() }
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

        guard !results.isEmpty else {
            let message = (json["message"] as? String) ?? "Couldn't read any classes from that photo."
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed(message)
            promptForPhotoSource()
            return
        }

        navigationItem.rightBarButtonItem?.isEnabled = true
        tableView.reloadData()
    }

    // MARK: - Review list

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { results.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scanRow", for: indexPath)
        let row = results[indexPath.row]
        cell.backgroundColor = UIColor(named: "background")
        cell.textLabel?.textColor = UIColor(named: "inverse")
        cell.detailTextLabel?.textColor = .systemGray
        cell.textLabel?.text = "Block \(row.block.uppercased()): \(row.subject)"
        cell.detailTextLabel?.text = [row.teacher, row.room].filter { !$0.isEmpty }.joined(separator: " · ")
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        editRow(at: indexPath.row)
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
            self.navigationItem.rightBarButtonItem?.isEnabled = !self.results.isEmpty
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.results[index].subject = alert.textFields?[0].text ?? row.subject
            self.results[index].teacher = alert.textFields?[1].text ?? row.teacher
            self.results[index].room = alert.textFields?[2].text ?? row.room
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        }))
        present(alert, animated: true)
    }

    // MARK: - Confirm and save

    @objc private func saveAll() {
        guard !results.isEmpty else { return }
        showLoader(text: "Saving your classes...")
        saveNextClass(index: 0)
    }

    // One block at a time, same reasoning as resetClasses (HQ-649): each write is
    // self-contained, so a failure partway through leaves everything before it durably
    // saved rather than losing the whole batch.
    private func saveNextClass(index: Int) {
        guard index < results.count else {
            hideLoader(completion: { [weak self] in
                ProgressHUD.colorAnimation = .green
                ProgressHUD.succeed("Classes saved")
                self?.navigationController?.popViewController(animated: true)
            })
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
