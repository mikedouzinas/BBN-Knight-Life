//
//  Extensions.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.
//

import Foundation
import UIKit

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
    func isInThroughDate(date: Date) -> Bool {
        let index = self.distance(of: "-")
        guard let ind = index else {
            return false
        }
        
        let date1 = self.prefix(ind)
        let date2 = self.suffix(self.count-(ind+1))
        if date.isBetweenTimeFrame(date1: "\(date1)".startOrEndDate(isStart: true) ?? Date(), date2: "\(date2)".startOrEndDate(isStart: false) ?? Date()) {
            return true
        }
        return false
    }
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
            "hh:mma"
        ]
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        for format in formats {
            dateFormatter.timeZone = TimeZone(abbreviation: "EST")
            dateFormatter.dateFormat = format
            if let convertedDate = dateFormatter.date(from: self) {
//                convertedDate
                return convertedDate
            }
        }
        return nil
    }
    func startOrEndDate(isStart: Bool) -> Date? {
        let dateFormatter = DateFormatter()
        
        let formats: [String] = [
            "EEEE, MMMM dd, yyyy",
            "dd MMM yyyy HH:mm"
        ]
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.amSymbol = "am"
        dateFormatter.pmSymbol = "pm"
        for format in formats {
            dateFormatter.dateFormat = format
            if let convertedDate = dateFormatter.date(from: self) {
                let calendar = Calendar.current
                var dateComponents = DateComponents()
                dateComponents.weekday = calendar.component(.weekday, from: convertedDate)
                dateComponents.year = calendar.component(.year, from: convertedDate)
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
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
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

extension UIImageView {
    
    public func loadGif(name: String) {
        DispatchQueue.global().async {
            let image = UIImage.gif(name: name)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
    @available(iOS 9.0, *)
    public func loadGif(asset: String) {
        DispatchQueue.global().async {
            let image = UIImage.gif(asset: asset)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
}

extension UIImage {
    
    public class func gif(data: Data) -> UIImage? {
        // Create billSource from data
        guard let billSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("SwiftGif: billSource for the image does not exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(billSource)
    }
    
    public class func gif(url: String) -> UIImage? {
        // Validate URL
        guard let bundleURL = URL(string: url) else {
            print("SwiftGif: This image named \"\(url)\" does not exist")
            return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(url)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    public class func gif(name: String) -> UIImage? {
        // Check for existance of gif
        guard let bundleURL = Bundle.main
                .url(forResource: name, withExtension: "gif") else {
            print("SwiftGif: This image named \"\(name)\" does not exist")
            return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    @available(iOS 9.0, *)
    public class func gif(asset: String) -> UIImage? {
        // Create billSource from assets catalog
        guard let dataAsset = NSDataAsset(name: asset) else {
            print("SwiftGif: Cannot turn image named \"\(asset)\" into NSDataAsset")
            return nil
        }
        
        return gif(data: dataAsset.data)
    }
    
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
    
    internal class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        // Check if one of them is nil
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        // Swap for modulo
        if a! < b! {
            let c = a
            a = b
            b = c
        }
        
        // Get greatest common divisor
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b! // Found it
            } else {
                a = b
                b = rest
            }
        }
    }
    
    internal class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    internal class func animatedImageWithSource(_ billSource: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(billSource)
        var images = [CGImage]()
        var delays = [Int]()
        
        // Fill arrays
        for i in 0..<count {
            // Add image
            if let image = CGImageSourceCreateImageAtIndex(billSource, i, nil) {
                images.append(image)
            }
            
            // At it's delay in cs
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            billSource: billSource)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        // Calculate full duration
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        // Get frames
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        // Heyhey
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
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
        var gifImage = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        if isLarge {
            gifImage.frame = view.bounds
            gifImage.contentMode = .scaleAspectFill
        }
        else {
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
    func showLoader(text: String) {
        let alert = UIAlertController(title: nil, message: "\(text)", preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: {
        })
    }
    func showConfirmation(title: String, message: String) {
        
    }
    func hideLoader(completion: (() -> Void)?) {
        dismiss(animated: true, completion: {
            completion!()
        })
    }
    func getScheduleFor(date: Date) -> CustomWeekday {
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd"
        formatter1.dateStyle = .full
        let stringDate = formatter1.string(from: date)
        let index = stringDate.firstIndex(of: ",")
        let weekday = stringDate.prefix(upTo: index!).lowercased()
        var currentDay = [block]()
        let lunchDays = getLunchDays(weekDay: weekday)
        currentDay = lunchDays.blocks
//        if date.isBetweenTimeFrame(date1: "11 Jun 2022 04:00".startOrEndDate(isStart: true) ?? Date(), date2: "02 Sep 2022 04:00".startOrEndDate(isStart: false) ?? Date()) {
//            currentDay = [block]()
//            return CustomWeekday(blocks: currentDay, weekday: String(weekday), date: date)
//        }
        for x in LoginVC.specialSchedules {
            if x.key.isInThroughDate(date: date) {
                currentDay = [block]()
                return CustomWeekday(blocks: currentDay, weekday: String(weekday), date: date)
            }
            if x.key.lowercased() == stringDate.lowercased() {
                if !((LoginVC.blocks["l-\(weekday)"] as? String) ?? "").lowercased().contains("2") {
                    currentDay = x.value.specialSchedulesL1
                }
                else {
                    currentDay = x.value.specialSchedules
                }
                return CustomWeekday(blocks: currentDay, weekday: String(weekday), date: date)
            }
        }
        return CustomWeekday(blocks: currentDay, weekday: String(weekday), date: date)
    }
    func getLunchDays(weekDay: String) -> (blocks: [block], selectedDay: Int) {
        var weekdayBlocks = [block]()
        var selectedDay = 0
//        print("weekday: \(weekDay)")
        let lowercaseWeekday = weekDay.lowercased()
        switch lowercaseWeekday {
        case "monday":
            if ((LoginVC.blocks["l-monday"] as? String) ?? "").lowercased().contains("2") {
                weekdayBlocks = defaultSchedules["monday"]?.L2 ?? [block]()
            }
            else {
                weekdayBlocks = defaultSchedules["monday"]?.L1 ?? [block]()
            }
            selectedDay = 0
            
        case "tuesday":
            if ((LoginVC.blocks["l-tuesday"] as? String) ?? "").lowercased().contains("2") {
                weekdayBlocks = defaultSchedules["tuesday"]?.L2 ?? [block]()
            }
            else {
                weekdayBlocks = defaultSchedules["tuesday"]?.L1 ?? [block]()
            }
            selectedDay = 1
        case "wednesday":
            if ((LoginVC.blocks["l-wednesday"] as? String) ?? "").lowercased().contains("2") {
                weekdayBlocks = defaultSchedules["wednesday"]?.L2 ?? [block]()
            }
            else {
                weekdayBlocks = defaultSchedules["wednesday"]?.L1 ?? [block]()
            }
            selectedDay = 2
        case "thursday":
            if ((LoginVC.blocks["l-thursday"] as? String) ?? "").lowercased().contains("2") {
                weekdayBlocks = defaultSchedules["thursday"]?.L2 ?? [block]()
            }
            else {
                weekdayBlocks = defaultSchedules["thursday"]?.L1 ?? [block]()
            }
            selectedDay = 3
        case "friday":
            if ((LoginVC.blocks["l-friday"] as? String) ?? "").lowercased().contains("2") {
                weekdayBlocks = defaultSchedules["friday"]?.L2 ?? [block]()
            }
            else {
                weekdayBlocks = defaultSchedules["friday"]?.L1 ?? [block]()
            }
            selectedDay = 4
        default:
            weekdayBlocks = [block]()
            selectedDay = 10
        }
        return (weekdayBlocks, selectedDay)
    }
    func setNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "MM-dd-yyyy hh:mm a Z"
        LoginVC.upcomingDays = [CustomWeekday]()
        var z = 0
        for i in 0...13 {
            let tempDate = calendar.date(byAdding: .day, value: i, to: Date())!
            let tempWeekday = getScheduleFor(date: tempDate)
            LoginVC.upcomingDays.append(tempWeekday)
            if ((LoginVC.blocks["notifs"] as? String) ?? "") == "true" {
                for x in tempWeekday.blocks {
                    if z < 64 {
                        addNotif(x: x, weekDay: tempWeekday.weekday, date: tempWeekday.date)
                        z+=1
                    }
                    else {
                        break
                    }
                    
                }
            }
        }
//        UNUserNotificationCenter.current().get
//        UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { notifs in
//            for x in notifs {
//                print("identifier: \(x.identifier) \n date: \(dateFormatter.string(from: calendar.date(from:(x.trigger as! UNCalendarNotificationTrigger).dateComponents) ?? Date()))")
//            }
//        })
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
        
        // 2
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        if x.block != "N/A" {
            var tile = ((LoginVC.blocks[x.block] ?? "") as? String) ?? ""
            if tile == "" {
                tile = "\(x.block) Block"
            }
            else if tile.contains("~") {
                let array = tile.getValues()
                let num = weekNum - 2
                
                tile = "\(array[0]) \(array[2].replacingOccurrences(of: "N/A", with: ""))"
                if num >= 0 && num <= 4 && !(LoginVC.classMeetingDays["\(x.block.lowercased())"]?[num] ?? true) {
                    tile = "\(x.block) Block"
                }
            }
            content.title = "5 Minutes Until \(tile)"
            // Write/Set Value
        }
        else {
            if x.name.lowercased().contains("passing") {
                content.title = "No Class - \(x.name)"
            }
            else {
                content.title = "5 Minutes Until \(x.name)"
            }
            
        }
        
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
