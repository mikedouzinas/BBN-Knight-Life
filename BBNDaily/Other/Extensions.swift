//
//  Extensions.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.
//

import Foundation
import UIKit
import Firebase
// `Auth` for the ID token the feedback POST sends. `import Firebase` alone does not re-export it.
import FirebaseAuth
import ProgressHUD

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    @objc func dismissKeyboard() {
        view.unbindToKeyboard()
        view.endEditing(true)
    }
}

extension String {
//    func getDateValue() -> Date {
//        let calendar = Calendar.current
//        let time2 = self.prefix(5)
//        let m2 = time2.replacingOccurrences(of: time2.prefix(3), with: "")
//        var amOrPm2 = 0
//        if self.contains("pm") && !time2.prefix(2).contains("12") {
//            amOrPm2 = 12
//        }
//        let t2 = calendar.date(
//            bySettingHour: ((Int(time2.prefix(2)) ?? 0)+amOrPm2),
//            minute: (Int(m2) ?? 0),
//            second: 0,
//            of: Date())!
//        return t2
//    }
    func getValues() -> [String]{
        var fullName = self
        let subject = String(fullName.prefix(upTo: fullName.firstIndex(of: "~") ?? fullName.startIndex)).setNotAvailable()
        fullName.removeSubrange(subject.startIndex...(fullName.firstIndex(of: "~") ?? fullName.startIndex))
        let teacher = String(fullName.prefix(upTo: fullName.firstIndex(of: "~") ?? fullName.startIndex)).setNotAvailable()
        fullName.removeSubrange(subject.startIndex...(fullName.firstIndex(of: "~") ?? fullName.startIndex))
        let room = String(fullName.prefix(upTo: fullName.firstIndex(of: "~") ?? fullName.startIndex)).setNotAvailable()
        fullName.removeSubrange(subject.startIndex...(fullName.firstIndex(of: "~") ?? fullName.startIndex))
        return [subject, teacher, room, fullName]
    }
    
    func setNotAvailable() -> String {
        if self.isEmpty || self == "" {
            return "N/A"
        }
        return self
    }

    /// The inverse of `setNotAvailable()`, for a label that should show nothing rather than "N/A".
    ///
    /// `getValues()` substitutes "N/A" for an empty field so that a caller building one string out
    /// of subject/teacher/room has something to print. A caller with a DEDICATED label per field
    /// wants the opposite: an empty label it can hide. Without this the two conventions collide and
    /// a free block, whose teacher and room are legitimately empty, reads as "Free / N/A".
    func blankIfNotAvailable() -> String {
        self == "N/A" ? "" : self
    }
    func getDayOfWeek() -> Int? {
        let formatter  = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let todayDate = formatter.date(from: self) else { return nil }
        let myCalendar = Calendar(identifier: .gregorian)
        let weekDay = myCalendar.component(.weekday, from: todayDate)
        return weekDay
    }
}
extension Int {
    func switchBlock() -> String {
        switch self {
        case 0:
            return "a"
        case 1:
            return "b"
        case 2:
            return "c"
        case 3:
            return "d"
        case 4:
            return "e"
        case 5:
            return "f"
        default:
            return "g"
        }
    }
}
extension UIView {
    func dropShadow(scale: Bool = true, radius: CGFloat = 3) {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = .zero
        layer.shadowRadius = radius
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    func unbindToKeyboard() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
}

extension UITableView {
    
    func setEmptyMessage(_ message: String) {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height))
        messageLabel.text = message
        messageLabel.textColor = UIColor(named: "inverse")
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.sizeToFit()
        
        self.backgroundView = messageLabel
        self.separatorStyle = .none
    }
    func restore() {
        self.backgroundView = nil
        self.separatorStyle = .singleLine
    }
}
extension Date {
    mutating func addEventsToToday() {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = calendar.component(.hour, from: self)
        dateComponents.minute = calendar.component(.minute, from: self)
        dateComponents.day = calendar.component(.day, from: Date())
        dateComponents.month = calendar.component(.month, from: Date())
        dateComponents.year = calendar.component(.year, from: Date())
        self = calendar.date(from: dateComponents) ?? Date()
    }
    func isBetweenTimeFrame(date1: Date, date2: Date) -> Bool {
        
        if self >= date1 && self <= date2
        {
            return true
        }
        return false
    }
    func getTimeBetween(to toDate: Date) -> TimeInterval  {
        let delta = toDate.timeIntervalSince(self)
        return delta
    }
}
extension UITableView {
    func scrollToBottom(indexPath: IndexPath){
        DispatchQueue.main.async {
            self.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

extension String {
    func stringDateFromMultipleFormats(preferredFormat: Int) -> String? {
        let dateformatter = DateFormatter()
        let formats: [String] = [
            "yyyy-MM-dd'T'hh:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSS",
            "yyyy-MM-dd'T'hh:mm:ss.SSS",
            "yyyy-MM-dd'T'hh:mm:ss.SS",
            "yyyy-MM-dd'T'hh:mm:ss.S",
            "dd MMM yyyy HH:mm",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "MM/dd/20yy"
        ]
        dateformatter.locale = Locale(identifier: "your_loc_id")
        
        for format in formats {
            dateformatter.dateFormat = format
            if let convertedDate = dateformatter.date(from: self) {
                dateformatter.timeZone = TimeZone(abbreviation: "EST")
                switch preferredFormat {
                case 0:
                    dateformatter.dateFormat = "dd MMM yyyy HH:mm"
                case 1:
                    dateformatter.dateFormat = "MM/dd/yy"
                case 2:
                    dateformatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
                case 3:
                    dateformatter.dateFormat = "dd MMM yy"
                case 4:
                    dateformatter.dateFormat = "MMM dd, yyyy"
                case 5:
                    dateformatter.dateFormat = "yyyy-MM-dd"
                case 6:
                    dateformatter.dateFormat = "EE, MMM dd, yyyy"
                case 7:
                    dateformatter.dateFormat = "EEEE, MMMM dd, yyyy"
                case 8:
                    dateformatter.dateFormat = "MM-dd-yyyy"
                default:
                    dateformatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
                }
                return dateformatter.string(from: convertedDate)
            }
            
        }
        return nil
    }
    func dateFromMultipleFormats() -> Date? {
        let dateFormatter = DateFormatter()
        
        let formats: [String] = [
            "yyyy-MM-dd'T'hh:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "EEEE, MMMM dd, yyyy",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSZ",
            "yyyy-MM-dd'T'hh:mm:ss.SZ",
            "yyyy-MM-dd'T'hh:mm:ss.SSSS",
            "yyyy-MM-dd'T'hh:mm:ss.SSS",
            "yyyy-MM-dd'T'hh:mm:ss.SS",
            "yyyy-MM-dd'T'hh:mm:ss.S",
            "dd MMM yyyy HH:mm",
            "MMM dd yyyy",
            "hh:mma",
            "hh:mm"
        ]
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        for format in formats {
            dateFormatter.timeZone = TimeZone(abbreviation: "EST")
            dateFormatter.dateFormat = format
            
            if let convertedDate = dateFormatter.date(from: self) {
//                convertedDate
//                print("MATCH! \(convertedDate)")
                return convertedDate
            }
        }
        return nil
    }
    func startOrEndDate(isStart: Bool, year: String?) -> Date? {
        let dateFormatter = DateFormatter()
        
        let formats: [String] = [
            "EEEE, MMMM dd, yyyy",
            "dd MMM yyyy HH:mm",
            "dd MMM"
        ]
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        for format in formats {
            dateFormatter.dateFormat = format
            if let convertedDate = dateFormatter.date(from: self) {
                let calendar = Calendar.current
                var dateComponents = DateComponents()
                dateComponents.weekday = calendar.component(.weekday, from: convertedDate)
                if let year = year {
                    if year == "current" {
                        dateComponents.year = calendar.component(.year, from: Date())
                    }
                    else {
                        dateComponents.year = calendar.component(.year, from: Date()) + 1
                    }
                }
                else {
                    dateComponents.year = calendar.component(.year, from: convertedDate)
                }
                dateComponents.month = calendar.component(.month, from: convertedDate)
                dateComponents.day = calendar.component(.day, from: convertedDate)
                if isStart {
                    dateComponents.hour = 0
                    dateComponents.minute = 0
                }
                else {
                    dateComponents.hour = 23
                    dateComponents.minute = 59
                    dateComponents.second = 59
                }
//                convertedDate
                return calendar.date(from: dateComponents)
            }
        }
        return nil
    }
    func startDate() -> Date? {
        let dateFormatter = DateFormatter()
        
        let formats: [String] = [
            "EEEE, MMMM dd, yyyy"
        ]
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let convertedDate = dateFormatter.date(from: self) {
//                convertedDate
                return convertedDate
            }
        }
        return nil
    }
}

/// HQ-606. The old path decoded every GIF frame up front via `UIImage.animatedImage(with:)`,
/// which for the seasonal launch-screen GIFs measured 90-131 MB of simultaneous in-memory
/// frames, every launch. This decodes exactly one frame at a time from the `CGImageSource`,
/// on a timer matched to that frame's own delay, so peak memory is one frame instead of the
/// whole animation.
///
/// Owned by the `UIImageView` it animates via an associated object, so `loadGif` keeps its
/// original call shape (`imageView.loadGif(name:)`) and nothing above this file changes.
private final class GifFramePlayer {
    private let source: CGImageSource
    private let frameCount: Int
    private let delaysMs: [Int]
    private weak var imageView: UIImageView?
    private var index = 0
    private var timer: Timer?

    init?(data: Data, imageView: UIImageView) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("SwiftGif: billSource for the image does not exist")
            return nil
        }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        self.source = source
        self.frameCount = count
        self.delaysMs = (0..<count).map { Int(UIImage.delayForImageAtIndex($0, billSource: source) * 1000) }
        self.imageView = imageView
    }

    func start() {
        showFrame(at: 0)
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }

    private func showFrame(at index: Int) {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { return }
        imageView?.image = UIImage(cgImage: cgImage)
    }

    private func scheduleNext() {
        let delaySeconds = Double(max(delaysMs[index], 10)) / 1000.0
        timer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.index = (self.index + 1) % self.frameCount
            self.showFrame(at: self.index)
            self.scheduleNext()
        }
    }
}

extension UIImageView {
    private static var gifPlayerKey: UInt8 = 0

    private var gifPlayer: GifFramePlayer? {
        get { objc_getAssociatedObject(self, &UIImageView.gifPlayerKey) as? GifFramePlayer }
        set { objc_setAssociatedObject(self, &UIImageView.gifPlayerKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    public func loadGif(name: String) {
        DispatchQueue.global().async {
            guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif"),
                  let imageData = try? Data(contentsOf: bundleURL) else {
                print("SwiftGif: This image named \"\(name)\" does not exist")
                return
            }
            DispatchQueue.main.async { self.startGif(data: imageData) }
        }
    }

    @available(iOS 9.0, *)
    public func loadGif(asset: String) {
        DispatchQueue.global().async {
            guard let imageData = NSDataAsset(name: asset)?.data else {
                print("SwiftGif: Cannot turn image named \"\(asset)\" into NSDataAsset")
                return
            }
            DispatchQueue.main.async { self.startGif(data: imageData) }
        }
    }

    private func startGif(data: Data) {
        gifPlayer?.stop()
        gifPlayer = GifFramePlayer(data: data, imageView: self)
        gifPlayer?.start()
    }
}

extension UIImage {

    internal class func delayForImageAtIndex(_ index: Int, billSource: CGImageSource!) -> Double {
        var delay = 0.1
        
        // Get dictionaries
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(billSource, index, nil)
        let gifPropertiesPointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 0)
        if CFDictionaryGetValueIfPresent(cfProperties, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque(), gifPropertiesPointer) == false {
            return delay
        }
        
        let gifProperties:CFDictionary = unsafeBitCast(gifPropertiesPointer.pointee, to: CFDictionary.self)
        
        // Get delay time
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as? Double ?? 0
        
        if delay < 0.01 {
            delay = 0.01 // Make sure they're not too fast
        }
        
        return delay
    }
}

extension UIImageView {
    func downloaded(from url: URL, contentMode mode: ContentMode = .scaleAspectFit) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
            else {
                LoginVC.profilePhoto.setImageForName("\(LoginVC.fullName)", backgroundColor: UIColor(named: "blue"), circular: false, textAttributes: nil, gradient: true)
                return
            }
            DispatchQueue.main.async() { [weak self] in
                self?.image = image
            }
        }.resume()
    }
    func downloaded(from link: String, contentMode mode: ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else { return }
        downloaded(from: url, contentMode: mode)
    }
}
extension UIView {
    @discardableResult
    func addBorders(edges: UIRectEdge,
                    color: UIColor,
                    inset: CGFloat = 0.0,
                    thickness: CGFloat = 1.0) -> [UIView] {

        var borders = [UIView]()

        @discardableResult
        func addBorder(formats: String...) -> UIView {
            let border = UIView(frame: .zero)
            border.backgroundColor = color
            border.translatesAutoresizingMaskIntoConstraints = false
            addSubview(border)
            addConstraints(formats.flatMap {
                NSLayoutConstraint.constraints(withVisualFormat: $0,
                                               options: [],
                                               metrics: ["inset": inset, "thickness": thickness],
                                               views: ["border": border]) })
            borders.append(border)
            return border
        }


        if edges.contains(.top) || edges.contains(.all) {
            addBorder(formats: "V:|-0-[border(==thickness)]", "H:|-inset-[border]-inset-|")
        }

        if edges.contains(.bottom) || edges.contains(.all) {
            addBorder(formats: "V:[border(==thickness)]-0-|", "H:|-inset-[border]-inset-|")
        }

        if edges.contains(.left) || edges.contains(.all) {
            addBorder(formats: "V:|-inset-[border]-inset-|", "H:|-0-[border(==thickness)]")
        }

        if edges.contains(.right) || edges.contains(.all) {
            addBorder(formats: "V:|-inset-[border]-inset-|", "H:[border(==thickness)]-0-|")
        }

        return borders
    }
}
class CustomLoader: UIViewController {
    var viewColor: UIColor = .black
    var setAlpha: CGFloat = 0
    var gifName: String = "demo"
    var isLarge = false
    lazy var transparentView: UIView = {
        let transparentView = UIView(frame: UIScreen.main.bounds)
        transparentView.backgroundColor = .clear
        transparentView.isUserInteractionEnabled = false
        return transparentView
    }()
    
    lazy var gifImage: UIImageView = {
        var gifImage = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        if isLarge {
            gifImage.frame = view.bounds
            gifImage.contentMode = .scaleAspectFill
        }
        else {
            if gifName == "demo" {
                gifImage.frame = CGRect(x: 0, y: 0, width: 200, height: 60)
            }
            gifImage.contentMode = .scaleAspectFit
        }
        gifImage.center = transparentView.center
        gifImage.isUserInteractionEnabled = false
        gifImage.loadGif(name: gifName)
        return gifImage
    }()
    convenience init() {
        self.init(name: nil, isLarge: nil)
    }
    
    init(name: String?, isLarge: Bool?) {
        self.gifName = name ?? "demo"
        self.isLarge = isLarge ?? false
        super.init(nibName: nil, bundle: nil)
    }
    
    // if this view controller is loaded from a storyboard, imageURL will be nil
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    func showLoaderView() {
        self.view.addSubview(self.transparentView)
        self.transparentView.addSubview(self.gifImage)
        self.transparentView.bringSubviewToFront(self.gifImage)
        //        UIApplication.shared.keyWindow?.addSubview(transparentView)
        
    }
    
    func hideLoaderView() {
        self.transparentView.removeFromSuperview()
    }
    
}

extension calendarTableViewCell {
    func animateView() {
        UIView.animate(withDuration: 0.5, animations: {
            self.backgroundColor = UIColor(named: "gold-bright")?.withAlphaComponent(0.5)
            self.contentView.backgroundColor = UIColor(named: "gold-bright")?.withAlphaComponent(0.5)
        }, completion: { _ in
            self.backgroundColor = UIColor(named: "background")
            self.contentView.backgroundColor = UIColor(named: "background")
        })
    }
}

extension UIViewController {
    func getTotalKnightLifeUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments(completion: { [self] (snapshot, error) in
            if error != nil {
                showMessage(title: "Error :(", subTitle: "Sorry, couldn't get the total Knight Life Users.")
            }
            else {
                let count = snapshot?.documents.count ?? 0
                showMessage(title: "New Knight Life Users Alert!", subTitle: "Knight Life now has \(count) users! Congrats!")
            }
        })
    }
    func showMessage(title: String, subTitle: String) {
        let alertController = UIAlertController(title: "\(title)", message: "\(subTitle)", preferredStyle: .alert)

        // add the buttons/actions to the view controller
        let cancelAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)

        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
    func showInputDialog(title:String? = nil,
                         subtitle:String? = nil,
                         actionTitle:String? = "Add",
                         cancelTitle:String? = "Cancel",
                         inputPlaceholder:String? = nil,
                         inputKeyboardType:UIKeyboardType = UIKeyboardType.default,
                         cancelHandler: ((UIAlertAction) -> Swift.Void)? = nil,
                         actionHandler: ((_ text: String?) -> Void)? = nil) {
        
        let alert = UIAlertController(title: title, message: subtitle, preferredStyle: .alert)
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = inputPlaceholder
            textField.keyboardType = inputKeyboardType
        }
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { (action:UIAlertAction) in
            guard let textField =  alert.textFields?.first else {
                actionHandler?(nil)
                return
            }
            actionHandler?(textField.text)
        }))
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: cancelHandler))
        
        self.present(alert, animated: true, completion: nil)
    }
    /// The blocking "working on it" indicator.
    ///
    /// ProgressHUD, not a hand-built UIAlertController. The alert version put a spinner into an
    /// alert's view with its own constraints while UIKit laid out the message independently, so
    /// the spinner and the text were positioned by two different systems that never agreed -
    /// which is why it read as off-centre with the spinner floating above the words, and why it
    /// was off by a different amount at every message length and Dynamic Type size.
    ///
    /// ProgressHUD is what every other status in this app already uses (`ProgressHUD.succeed`,
    /// `.failed`), so this also makes the loading state look like the states either side of it
    /// instead of like a different app.
    func showLoader(text: String) {
        ProgressHUD.animationType = .circleStrokeSpin
        ProgressHUD.colorAnimation = UIColor(named: "inverse") ?? .label
        ProgressHUD.animate(text, interaction: false)
    }
    func showConfirmation(title: String, message: String) {
        
    }
    /// Dismisses whatever `showLoader` put up, then runs the follow-on.
    ///
    /// The completion is invoked directly rather than through `dismiss(animated:completion:)`,
    /// because ProgressHUD is not a presented view controller - calling `dismiss` here would
    /// dismiss whatever screen the caller is ON. That is also why the completion is optional
    /// now: the old version force-unwrapped it and crashed on `hideLoader(completion: nil)`.
    func hideLoader(completion: (() -> Void)?) {
        ProgressHUD.dismiss()
        completion?()
    }

    /// Asks the student what went wrong and posts it, in their own words.
    ///
    /// Lives on `UIViewController` so both Settings and the scan review screen offer it from the
    /// same code - the report that matters most is the one sent from the screen where the thing
    /// went wrong, while the student can still see it.
    ///
    /// Fire and mostly forget, on purpose. It reports success or failure and never blocks
    /// anything: a student who cannot send feedback has already hit one problem, and making them
    /// sit through a second failure to tell us about the first is the wrong trade.
    ///
    /// - Parameter context: where they were, e.g. "schedule-scan". Stored alongside the message so
    ///   a week of reports can be read by area instead of one at a time.
    func promptForFeedback(context: String) {
        let alert = UIAlertController(
            title: "Report a Problem",
            message: "What went wrong? This goes straight to whoever maintains the app. Say what you expected and what you got.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "It read my B block as the wrong class"
            field.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { [weak self] _ in
            let text = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            self?.sendFeedback(message: text, context: context)
        }))
        present(alert, animated: true)
    }

    /// The feedback endpoint, on the canonical `www.` host for the same reason the scan endpoint
    /// is - a cross-host 308 drops the Authorization header. scripts/check-app-urls.sh enforces it.
    private static let feedbackEndpoint = "https://www.mikeveson.com/knight-life/api/student/feedback"

    private func sendFeedback(message: String, context: String) {
        guard let url = URL(string: UIViewController.feedbackEndpoint) else { return }
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"

        Auth.auth().currentUser?.getIDToken(completion: { token, error in
            guard let token = token, error == nil else {
                DispatchQueue.main.async {
                    ProgressHUD.colorAnimation = .red
                    ProgressHUD.failed("Couldn't verify your sign-in. Try again.")
                }
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "message": message,
                "context": context,
                "appVersion": "\(version) (\(build))",
            ])

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard error == nil, (200...299).contains(status) else {
                        // The status is named rather than blamed on the network.
                        //
                        // "Check your connection" is right for a transport failure and actively
                        // misleading for anything else - and the first time this ran the endpoint
                        // was not deployed yet, so it answered 404 and the app told Mike his
                        // connection was bad. A student chasing their wifi over a server problem
                        // never reports it, which defeats the entire point of a feedback button.
                        ProgressHUD.colorAnimation = .red
                        if error != nil {
                            ProgressHUD.failed("Couldn't send that. Check your connection and try again.")
                        } else if status == 404 {
                            ProgressHUD.failed("Reporting isn't available yet in this version. Sorry.")
                        } else if status == 401 || status == 403 {
                            ProgressHUD.failed("Couldn't verify your sign-in. Sign out and back in.")
                        } else {
                            ProgressHUD.failed("Couldn't send that (error \(status)). Try again.")
                        }
                        print("feedback POST failed: status \(status), error \(String(describing: error))")
                        return
                    }
                    ProgressHUD.colorAnimation = .green
                    ProgressHUD.succeed("Thanks - that was sent")
                }
            }.resume()
        })
    }
    // getScheduleFor lived here and is gone. HQ-607.
    //
    // It was the v1 way of working out a day, superseded by resolveDay, and it had zero
    // callers anywhere in the project. It also carried a locale crash that could never fire
    // precisely because nothing called it: it set `dateFormat` and then `dateStyle`, which
    // silently discards the format, then force-unwrapped `stringDate.firstIndex(of: ",")`.
    // In any locale whose full date has no comma -- French renders `lundi 15 septembre 2025`
    // -- that unwrap is nil.
    //
    // The lesson is worth more than the code: NEVER DERIVE MEANING FROM A FORMATTED DISPLAY
    // STRING. The same mistake, made in SecretSchedule, is why every legacy schedule document
    // is keyed on a locale-dependent sentence and why that collection cannot be range-queried
    // (HQ-603). resolveDay takes its weekday from a DateFormatter with an explicit "EEEE"
    // format and never reads a display string for meaning.
    
    // MARK: The single answer to "what does this date look like"
    //
    // Before this existed there were three resolvers that each knew different things:
    //
    //   getScheduleFor     read the v1 special-schedules collection, knew through-dates,
    //                      knew nothing about v2 special days or breaks. Notifications used it.
    //   getSchedule        read v2 special days, knew nothing about breaks. Nothing used it.
    //   CalendarVC inline  read v2 special days AND breaks. The calendar used it.
    //
    // So on the twelve dates where v1 and v2 disagree, what a student saw on screen and what
    // their phone notified them about came from different data. Two of those dates had v1
    // deliberately blanked to prompt an app update, which also silenced notifications for
    // five real school days.
    //
    // Everything that needs a day now goes through here, so a disagreement of that kind cannot
    // be expressed. Adding a new consumer must not mean adding a fourth resolver.
    // HQ-661: reads sideMenu/publications, falling back to SideMenuEntry.defaultPublications
    // on any failure - no document, a read error, or every entry in it failing to parse.
    // A malformed individual entry is dropped rather than crashing the whole fetch, same
    // reasoning as resolveDay's malformed-day handling elsewhere in this file: one bad row
    // is a menu missing one row, not a broken menu.
    func fetchSideMenuPublications(completion: @escaping ([SideMenuEntry]) -> Void) {
        Firestore.firestore().collection("sideMenu").document("publications").getDocument { snapshot, error in
            guard error == nil, let rawEntries = snapshot?.data()?["entries"] as? [[String: Any]], !rawEntries.isEmpty else {
                completion(SideMenuEntry.defaultPublications)
                return
            }
            let parsed = rawEntries.compactMap { dict -> SideMenuEntry? in
                guard let title = dict["title"] as? String, !title.isEmpty,
                      let urlString = dict["url"] as? String, !urlString.isEmpty else { return nil }
                return SideMenuEntry(
                    title: title,
                    iconName: (dict["iconName"] as? String) ?? "link",
                    textImageName: dict["textImageName"] as? String,
                    urlString: urlString,
                    order: (dict["order"] as? Int) ?? Int.max,
                    visible: (dict["visible"] as? Bool) ?? true
                )
            }
            let visible = parsed.filter { $0.visible }.sorted { $0.order < $1.order }
            completion(visible.isEmpty ? SideMenuEntry.defaultPublications : visible)
        }
    }

    // Asset catalog first (the bundled publication logos), then an SF Symbol of the same
    // name, then a generic fallback - so a Firestore entry naming an icon that doesn't
    // exist gets a plain link icon instead of crashing on a force-unwrapped UIImage.
    func resolveSideMenuIcon(_ name: String) -> UIImage {
        UIImage(named: name) ?? UIImage(systemName: name) ?? UIImage(systemName: "link")!
    }

    func resolveDay(date: Date) -> ResolvedDay {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d" // v2 keys are not zero padded
        let stringDate = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "EEEE"
        let weekdayName = dateFormatter.string(from: date)
        let weekdayIndex = getWeekdayAsInt(weekdayName)

        // 1. An explicitly published day always wins.
        if let value = LoginVC.specialDays[stringDate] {
            switch value.type {
            case "noschool":
                return ResolvedDay(blocks: [], weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                                   date: date, kind: .noSchool(reason: value.reason ?? "No Class"))
            case "image":
                var blocks = [block]()
                for scheduleBlock in value.blocks ?? [] {
                    blocks += getNextBlock(scheduleBlock: scheduleBlock) ?? []
                }
                return ResolvedDay(blocks: blocks, weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                                   date: date, kind: .image(url: value.imageUrl ?? ""))
            default:
                var blocks = [block]()
                for scheduleBlock in value.blocks ?? [] {
                    blocks += getNextBlock(scheduleBlock: scheduleBlock) ?? []
                }
                return ResolvedDay(blocks: blocks, weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                                   date: date, kind: .classes)
            }
        }

        // 2. Breaks. This check is why notifications could not simply be pointed at the old
        //    getSchedule: it did not know about breaks, so it would have scheduled class
        //    alerts straight through summer.
        for singularBreak in LoginVC.breaks where isDateInBreak(date: date, breakPeriod: singularBreak) {
            return ResolvedDay(blocks: [], weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                               date: date, kind: .noSchool(reason: singularBreak.reason))
        }

        // 3. Weekends carry no regular schedule.
        if weekdayIndex == 10 {
            return ResolvedDay(blocks: [], weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                               date: date, kind: .weekend)
        }

        // 4. Outside the school year there is no regular schedule to fall back on.
        //
        //    This is the inversion. Before it, an unknown weekday fell straight through to
        //    the weekly pattern, so a gap in the calendar produced a confident wrong answer:
        //    on 2026-08-19, mid-summer, the app showed students a full seven-block Wednesday
        //    because no break happened to cover the date.
        //
        //    Both directions are wrong when the calendar goes stale. The difference is what
        //    the wrongness does. Falling through wakes a student for a class that does not
        //    exist; stopping here says nothing. Point the failure at silence.
        //
        //    Note the guard: this only fires when the term is actually known. A missing or
        //    unreadable term leaves the old behaviour in place, because "the read failed" must
        //    never render as "there is no school today" for the whole school.
        if let term = LoginVC.term, !isDateInTerm(date: date, term: term) {
            return ResolvedDay(blocks: [], weekdayIndex: weekdayIndex, weekdayName: weekdayName,
                               date: date, kind: .outsideTerm(reason: term.reason))
        }

        let regular = getRegularSchedule(weekday: weekdayName)
        return ResolvedDay(blocks: regular.blocks, weekdayIndex: regular.selectedDay,
                           weekdayName: weekdayName, date: date, kind: .classes)
    }

    // Inclusive on both ends: the first and last day of classes are inside the term.
    //
    // Deliberately returns TRUE when the dates do not parse. An unparseable term is a broken
    // read, and a broken read must not tell the school there is no class. Same reasoning as
    // the nil check in resolveDay, applied one level down, because a malformed string and a
    // missing document are the same kind of failure.
    func isDateInTerm(date: Date, term: Term) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        guard let start = dateFormatter.date(from: term.startDate),
              let end = dateFormatter.date(from: term.endDate),
              start <= end else {
            return true
        }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return calendar.startOfDay(for: start) <= day && day <= calendar.startOfDay(for: end)
    }

    // Inclusive on both ends. Break dates are stored as yyyy/M/d strings.
    func isDateInBreak(date: Date, breakPeriod: Break) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        guard let start = dateFormatter.date(from: breakPeriod.startDate),
              let end = dateFormatter.date(from: breakPeriod.endDate) else {
            return false
        }
        // Compare whole days, so a break ending "today" still counts today.
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return calendar.startOfDay(for: start) <= day && day <= calendar.startOfDay(for: end)
    }

    // MARK: Generael purpose getting schedule for v2 format
    func getSchedule(date: Date) -> (blocks: [block], selectedDay: Int) {
        let resolved = resolveDay(date: date)
        return (resolved.blocks, resolved.weekdayIndex)
    }
    
    // MARK: get default schedule for a certain day with v2 format
    func getRegularSchedule(weekday: String) -> (blocks: [block], selectedDay: Int) {
        var weekdayBlocks = [block]()
//        print("weekday: \(weekday)")
        let lowercaseWeekday = weekday.lowercased()
        
        for scheduleBlock in regularSchedule[lowercaseWeekday] ?? [] {
            weekdayBlocks += getNextBlock(scheduleBlock: scheduleBlock ) ?? []
        }
        
        // Can't sort blocks yet because need to deal with 12h time format
//        return (sortBlocks(weekdayBlocks), selectedDay)
        return (weekdayBlocks, getWeekdayAsInt(lowercaseWeekday))
    }
    
    func getNextBlock(scheduleBlock: Event) -> [block]? {
        let blockType = scheduleBlock.type.lowercased()
        var blocks = [block]()
        
        // Block types of N/A are "temporary" while migrating schedule formats
        if blockType == "block" {
            blocks.append(block(name: scheduleBlock.name!, startTime: scheduleBlock.startTime!, endTime: scheduleBlock.endTime!, block: scheduleBlock.block!.count == 1 ? scheduleBlock.block!.uppercased() : "N/A"))
            return blocks
        }
        
        if blockType == "lunch" {
            blocks.append(block(name: "Lunch", startTime: scheduleBlock.startTime!, endTime: scheduleBlock.endTime!, block: "N/A"))
            return blocks
        }
        
        if blockType == "specific" {
            let filters = scheduleBlock.filter
            let matchMode = scheduleBlock.matchMode
            
            var matched = (matchMode == "all")
            
            for filt in filters ?? [] {
                if checkFilter(filterIn: filt, scheduleBlock: scheduleBlock) {
                    matched = true
                    if matchMode != "all" {
                        matched = true
                        break
                    }
                } else if matchMode == "all" {
                    matched = false
                    break
                }
            }
            
            if matched {
                for subBlock in scheduleBlock.contents ?? [] {
                    blocks += (getNextBlock(scheduleBlock: subBlock) ?? [])
                }
            }
            
            return blocks
        }
        
        return blocks
    }
    
    func checkFilter(filterIn: String, scheduleBlock: Event) -> Bool {
        let filter = filterIn.lowercased()
        
        // Filter is lunch block
        if filter == "l1" || filter == "l2" {
            if let userLunchPeriod = LoginVC.blocks["l-\(scheduleBlock.lunchBlock!.lowercased())"] as? String {
                return userLunchPeriod == "" || userLunchPeriod == "Not Set" || (userLunchPeriod == "1st Lunch" && filter == "l1") || (userLunchPeriod == "2nd Lunch" && filter == "l2")
            } else {
                return true
            }
        }
        
        // Filter is grade
        if let userGrade = (LoginVC.blocks["grade"] as? String)?.lowercased() {
            // If the user has no grade set, show it to them just in case
            return userGrade == "" || userGrade == filter
        } else {
            // Somehow the user has no grade
            return true
        }
    }
    
    func sortBlocks(_ blocks: [block]) -> [block] {
        // Sort the blocks while maintaining their original order when start and end times are the same
        return blocks.enumerated().sorted {
            let (index1, block1) = $0
            let (index2, block2) = $1
            if block1 < block2 {
                return true
            } else if block1 == block2 {
                return index1 < index2
            } else {
                return false
            }
        }.map { $0.1 } // Return the sorted blocks, ignoring the indices
    }
    
    func getWeekdayAsInt(_ weekday: String) -> Int {
        let lowercaseWeekday = weekday.lowercased()
        
        switch lowercaseWeekday {
        case "monday":
            return 0
        case "tuesday":
            return 1
        case "wednesday":
            return 2
        case "thursday":
            return 3
        case "friday":
            return 4
        default:
            return 10
        }
    }
    // MARK: End v2
    
    func nextWeekday(weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()

        guard let nextWeekday = calendar.nextDate(after: today,
                                                 matching: DateComponents(weekday: weekday),
                                                 matchingPolicy: .nextTime) else {
            fatalError("Couldn't find the next Weekday.")
        }

        return nextWeekday
    }
    // HQ-639. Local, per-block reminders stay as the offline fallback: a push (HQ-112) tells
    // a closed app that the schedule changed, but only a local notification can remind someone
    // mid-day about a block that hasn't changed. Push covers "the schedule is different than
    // you think"; this covers "it's almost time for the thing you already knew about."
    //
    // The old version walked a fixed 14 days and broke mid-day once 64 requests were used,
    // which meant a busy stretch silently ate the budget: whichever day happened to fill it
    // got every block, and every day after got nothing - not because it mattered less, but
    // because of where it fell in the loop. A day could also end up HALF scheduled, missing
    // whichever blocks came after the cap, which is its own kind of wrong: a student reminded
    // for first block and silently not for the rest reads as "nothing else today," not as
    // "the count ran out."
    //
    // This walks the same way but stops BEFORE a day that would go over budget, so the window
    // is whatever the schedule can fully afford rather than a guess. Every day that gets
    // notifications gets all of them.
    func setNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        LoginVC.upcomingDays = [ResolvedDay]()
        var scheduled = 0
        var budgetFull = false
        let notifsOn = ((LoginVC.blocks["notifs"] as? String) ?? "") == "true"
        let maxLookaheadDays = 14
        let requestBudget = 64
        for i in 0..<maxLookaheadDays {
            let tempDate = calendar.date(byAdding: .day, value: i, to: Date())!
            // resolveDay is the same call the calendar makes, so a notification can no longer
            // describe a different day from the one on screen.
            let day = resolveDay(date: tempDate)
            LoginVC.upcomingDays.append(day)
            guard notifsOn, day.hasClasses, !budgetFull else { continue }
            // `continue`, never `break`. This loop has a second job: every iteration appends
            // to LoginVC.upcomingDays, which CalendarVC walks to find "Next Day of Classes",
            // and setNotifications is the only thing that ever writes it. Leaving the loop
            // early to stop scheduling would also stop filling that list, so a student with
            // notifications ON would get a shorter calendar lookahead than one with them
            // off - a notification budget silently truncating an unrelated feature.
            //
            // budgetFull latches rather than being re-tested per day, so the window stays
            // contiguous. Without the latch a later, lighter day could slip under the cap
            // after a heavier one was skipped, which is exactly the "days silently missing
            // from the middle" shape this ticket set out to remove.
            guard scheduled + day.blocks.count <= requestBudget else {
                budgetFull = true
                continue
            }
            for x in day.blocks {
                addNotif(x: x, weekDay: day.weekdayName, date: day.date)
            }
            scheduled += day.blocks.count
        }
    }
    func getBlockOnDate(date: Date, time: String) -> Date {
        var dateComponents = DateComponents()
        let calendar = Calendar.current
        let convertedTime = time.dateFromMultipleFormats() ?? Date()
        dateComponents.hour = calendar.component(.hour, from: convertedTime)
        dateComponents.minute = calendar.component(.minute, from: convertedTime)
        dateComponents.day = calendar.component(.day, from: date)
        dateComponents.month = calendar.component(.month, from: date)
        dateComponents.year = calendar.component(.year, from: date)
        dateComponents.timeZone = .current
        
        return calendar.date(from: dateComponents) ?? Date()
    }
    func getTitleForBlock(x: block, weekNum: Int, notif: Bool) -> String {
        if x.block != "N/A" {
            var tile = ((LoginVC.blocks[x.block] ?? "") as? String) ?? ""
            if tile == "" {
                tile = "\(x.block) Block"
            }
            else if tile.contains("~") {
                let array = tile.getValues()
                var num = weekNum - 2
                
                tile = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                if num >= 0 && num <= 4 && !(LoginVC.classMeetingDays["\(x.block.lowercased())"]?[num] ?? true) {
                    tile = "Free (\(x.block))"
                }
            }
            if notif {
                return "5 Minutes Until \(tile)"
            }
            return tile
        }
        else {
            if x.name.lowercased().contains("passing") {
                if notif {
                    return "No Class - \(x.name)"
                }
                return x.name
            }
            else {
                if notif {
                    return "5 Minutes Until \(x.name)"
                }
                return x.name
            }
            
        }
    }
    func addNotif(x: block, weekDay: String, date: Date) {
        let calendar = Calendar.current
        let startTime = x.startTime.dateFromMultipleFormats() ?? Date()
        var reminderTime = startTime
        if !x.name.lowercased().contains("passing") {
            reminderTime = calendar.date(byAdding: .minute, value: -5, to: startTime)!
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = calendar.component(.hour, from: reminderTime)
        dateComponents.minute = calendar.component(.minute, from: reminderTime)
        dateComponents.day = calendar.component(.day, from: date)
        dateComponents.month = calendar.component(.month, from: date)
        dateComponents.year = calendar.component(.year, from: date)
        dateComponents.timeZone = .current
//        dateComponents.day
        var weekNum = 1
        switch weekDay {
        case "sunday":
            weekNum = 1
        case "monday":
            weekNum = 2
        case "tuesday":
            weekNum = 3
        case "wednesday":
            weekNum = 4
        case "thursday":
            weekNum = 5
        case "friday":
            weekNum = 6
        default:
            weekNum = 7
        }
//        dateComponents.weekday = weekNum
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "EST")
        dateFormatter.dateFormat = "MM-dd-yyyy hh:mm a Z"
        
//        print("Final Date: \(dateFormatter.string(from: calendar.date(from: dateComponents) ?? Date()))")
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        
        content.title = getTitleForBlock(x: x, weekNum: weekNum, notif: true)
        
        let randomIdentifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: randomIdentifier, content: content, trigger: trigger)
//        print("identifier: \(randomIdentifier)")
        // 3
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                print("something went wrong")
            }
//            print("Error?: \(error)")
        }
    }
}


let imageCache = NSCache<NSString, UIImage>()
extension UIImageView {
    var activityIndicator: UIActivityIndicatorView {
         let activityIndicator = UIActivityIndicatorView()
         activityIndicator.hidesWhenStopped = true
         activityIndicator.color = UIColor.black
         self.addSubview(activityIndicator)

         activityIndicator.translatesAutoresizingMaskIntoConstraints = false

         let centerX = NSLayoutConstraint(item: self,
                                          attribute: .centerX,
                                          relatedBy: .equal,
                                          toItem: activityIndicator,
                                          attribute: .centerX,
                                          multiplier: 1,
                                          constant: 0)
         let centerY = NSLayoutConstraint(item: self,
                                          attribute: .centerY,
                                          relatedBy: .equal,
                                          toItem: activityIndicator,
                                          attribute: .centerY,
                                          multiplier: 1,
                                          constant: 0)
         self.addConstraints([centerX, centerY])
         return activityIndicator
     }
    func loadImageUsingCacheWithUrlString(urlstring: String, completion: @escaping (Swift.Result<UIImage?, Error>) -> Void) {
        guard let url = URL(string: urlstring) else {
            print("url err")
            self.image = UIImage(named: "parking")
            completion(.success(self.image))
            return
        }
        self.image = nil
        let activityIndicator = self.activityIndicator
        activityIndicator.startAnimating()
        // check for cache first
        if let cachedImage = imageCache.object(forKey: NSString(string: urlstring)) {
            print("already cached :)")
            DispatchQueue.main.async {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
            }
            self.image = cachedImage
            completion(.success(self.image))
            return
        }
        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            guard let data = data, error == nil else {
                print("failed, error is \(String(describing: error?.localizedDescription))")
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                }
                completion(.failure(error!))
                return
            }

            DispatchQueue.main.async {
                if let image = UIImage(data: data) {
//                    print("correctly set cache data")
                    imageCache.setObject(image, forKey: NSString(string: urlstring))
                    DispatchQueue.main.async {
                        activityIndicator.stopAnimating()
                        activityIndicator.removeFromSuperview()
                    }
                    self.image = image
                    completion(.success(self.image))
                }

            }
        })
        task.resume()
    }
}

class PaddingLabel: UILabel {
    
    var insets = UIEdgeInsets.zero
    
    func padding(_ top: CGFloat, _ bottom: CGFloat, _ left: CGFloat, _ right: CGFloat) {
        self.frame = CGRect(x: 0, y: 0, width: self.frame.width + left + right, height: self.frame.height + top + bottom)
        insets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += insets.top + insets.bottom
            contentSize.width += insets.left + insets.right
            return contentSize
        }
    }
}

final class StretchyTableHeaderView: UIView {
    public let imageview: UIImageView = {
        let image = UIImageView()
        image.clipsToBounds = true
        return image
    } ()
    public let nameLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        // HQ-629: deliberate constant white, not a light/dark bug - this sits on a fixed
        // black overlay (below) for legibility over a photo, not on the app's adaptive
        // background, so it never needs to change with the system appearance.
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        label.dropShadow(scale: true, radius: 50)
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 8
        label.padding(2, 2, 8, 8)
        return label
    } ()
    private var imageViewHeight = NSLayoutConstraint()
    private var imageViewBottom = NSLayoutConstraint()
    private var containerView = UIView()
    private var containerViewHeight = NSLayoutConstraint()
    override init(frame: CGRect) {
        super.init(frame: frame)
        createViews()
        setViewConstraints()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    private func createViews() {
        addSubview(containerView)
        containerView.addSubview(imageview)
        addSubview(nameLabel)
    }
    func setViewConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalTo: containerView.widthAnchor),
            centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.widthAnchor.constraint(equalTo: imageview.widthAnchor).isActive = true
        containerViewHeight = containerView.heightAnchor.constraint(equalTo: self.heightAnchor)
        containerViewHeight.isActive = true
        
        imageview.translatesAutoresizingMaskIntoConstraints = false
        imageViewBottom = imageview.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        imageViewBottom.isActive = true
        imageViewHeight = imageview.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        imageViewHeight.isActive = true
        
        nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20).isActive = true
        nameLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 20).isActive = true
    }
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        containerViewHeight.constant = scrollView.contentInset.top
        let offsetY = -(scrollView.contentOffset.y + scrollView.contentInset.top)
        containerView.clipsToBounds = offsetY <= 0
        imageViewBottom.constant = offsetY >= 0 ? 0 : -offsetY / 2
        imageViewHeight.constant = max(offsetY + scrollView.contentInset.top, scrollView.contentInset.top)
    }
}
extension StringProtocol {
    func distance(of element: Element) -> Int? { firstIndex(of: element)?.distance(in: self) }
    func distance<S: StringProtocol>(of string: S) -> Int? { range(of: string)?.lowerBound.distance(in: self) }
}
extension String.Index {
    func distance<S: StringProtocol>(in string: S) -> Int { string.distance(to: self) }
}
extension Collection {
    func distance(to index: Index) -> Int { distance(from: startIndex, to: index) }
}
