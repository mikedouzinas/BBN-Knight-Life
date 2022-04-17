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
    func isBetweenTimeFrame(date1: Date, date2: Date) -> Bool {
        if self > date1 && self < date2
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
            "MM/dd/yyyy"
        ]
        dateformatter.locale = Locale(identifier: "your_loc_id")
        
        for format in formats {
            dateformatter.dateFormat = format
            if let convertedDate = dateformatter.date(from: self) {
                dateformatter.timeZone = TimeZone.current
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
            "",
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
            "MMM dd yyyy"
        ]
        dateFormatter.locale = Locale(identifier: "your_loc_id")
        
        for format in formats {
            dateFormatter.dateFormat = format
            dateFormatter.timeZone = TimeZone.current
            if let convertedDate = dateFormatter.date(from: self) {
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
}
