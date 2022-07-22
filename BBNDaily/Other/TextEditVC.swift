//
//  TextEditVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import Firebase

class TextEditVC: UIViewController, UITextViewDelegate {
    static var link: ClassPopupVC!
    @IBOutlet weak var TextView: UITextView!
//    @IBOutlet weak var textViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var downKeyboard: UIBarButtonItem!
    override func viewDidLoad() {
        TextView.delegate = self
        TextView.text = TextEditVC.link.TextView.text
        TextView.becomeFirstResponder()
        downKeyboard.image = nil
        downKeyboard.title = ""
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    @IBAction func pushDown(_ sender: UIBarButtonItem) {
        view.unbindToKeyboard()
        view.endEditing(true)
        downKeyboard.image = nil
        downKeyboard.title = ""
    }
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.textViewConstraint.constant == 0 {
                downKeyboard.image = UIImage(systemName: "keyboard.chevron.compact.down")
                self.textViewConstraint.constant = keyboardSize.height-100
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.textViewConstraint.constant != 0 {
            self.textViewConstraint.constant = 0
        }
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let maxLength = 300
        let currentString = (textView.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: text)
        
        return newString.count <= maxLength
    }
    @IBAction func save() {
        let db = Firestore.firestore()
        let memberDocs = db.collection("classes")
        let blockName = (LoginVC.blocks["\(ClassPopupVC.block)"] as? String) ?? "N/A"
        let doc = memberDocs.document(blockName)
        doc.setData(["homework":"\(TextView.text ?? "")"], merge: true)
        TextEditVC.link.TextView.text = "\(TextView.text ?? "")"
        TextView.resignFirstResponder()
        self.navigationController?.popViewController(animated: true)
    }
}
