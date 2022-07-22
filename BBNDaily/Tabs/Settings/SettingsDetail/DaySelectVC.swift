//
//  DaySelectVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import Firebase
import ProgressHUD

class DaySelectVC: UIViewController {
    @IBOutlet weak var MondaySwitch: UISwitch!
    @IBOutlet weak var TuesdaySwitch: UISwitch!
    @IBOutlet weak var WednesdaySwitch: UISwitch!
    @IBOutlet weak var ThursdaySwitch: UISwitch!
    @IBOutlet weak var FridaySwitch: UISwitch!
    static var link: ClassesOptionsPopupVC!
    static var isEditing = false
    var finalString = ""
    func alreadyExists(word: String) -> Bool {
        for selectedRow in DaySelectVC.link.Classes {
            if word == "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)" {
                return true
            }
        }
        return false
    }
    @IBAction func p(_ sender: Any) {
        // add block field
        let selectedRow = ClassesOptionsPopupVC.newClass
        finalString = "\(selectedRow.Subject)~\(selectedRow.Teacher)~\(selectedRow.Room)~\(selectedRow.Block)"
        
        let db = Firestore.firestore()
        print("IsEditing: \(DaySelectVC.isEditing)")
        if DaySelectVC.isEditing {
            let oldRow = ClassesOptionsPopupVC.editedClass
            let oldString = "\(oldRow.Subject)~\(oldRow.Teacher)~\(oldRow.Room)~\(oldRow.Block)"
            if finalString != oldString && alreadyExists(word: finalString) {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.showFailed("Class already exists!")
                return
            }
            let oldDoc = db.collection("classes")
            let doc = oldDoc.document(oldString)
            doc.getDocument(completion: { [self] (document, error) in
                if let document = document, document.exists {
                    let array = (document.data()?["members"] as? [[String: String]]) ?? [[String: String]]()
                    let homeworkText = (document.data()?["homework"] as? String) ?? ""
                    
                    let data2 = ["monday":MondaySwitch.isOn, "tuesday":TuesdaySwitch.isOn, "wednesday":WednesdaySwitch.isOn, "thursday":ThursdaySwitch.isOn, "friday":FridaySwitch.isOn] as [String : Any]
                    let data = ["name":"\(finalString)", "monday":MondaySwitch.isOn, "tuesday":TuesdaySwitch.isOn, "wednesday":WednesdaySwitch.isOn, "thursday":ThursdaySwitch.isOn, "friday":FridaySwitch.isOn, "members":array, "homework":homeworkText, "block":"\(oldRow.Block.uppercased())"] as [String : Any]
                    
                    // delete old one and change all of people's data to this one
                    for x in array {
                        let uid = (x["uid"] ?? "1234")
                        let personDoc = db.collection("users").document("\((uid))")
                        personDoc.setData(["\(oldRow.Block.replacingOccurrences(of: " Block", with: ""))":"\(finalString)"], merge: true)
                        if uid == ((LoginVC.blocks["uid"] as? String) ?? "") {
                            LoginVC.blocks["\(ClassesOptionsPopupVC.currentBlock)"] = finalString
                            LoginVC.classMeetingDays["\(ClassesOptionsPopupVC.currentBlock.lowercased())"] = [MondaySwitch.isOn, TuesdaySwitch.isOn, WednesdaySwitch.isOn, ThursdaySwitch.isOn, FridaySwitch.isOn]
                        }
                    }
                    if finalString == oldString {
                        doc.setData(data2, merge: true)
                    }
                    else {
                        let currDoc = db.collection("classes").document(finalString)
                        currDoc.setData(data, merge: true)
                        doc.delete() { err in
                            if let err = err {
                                print("Error removing document: \(err)")
                            } else {
                                print("Document successfully removed!")
                            }
                        }
                    }
                    
                    DaySelectVC.link.Classes.remove(at: ClassesOptionsPopupVC.indexPath.row)
                    DaySelectVC.link.Classes.append(selectedRow)
                    DaySelectVC.link.filteredClasses = DaySelectVC.link.Classes
                    DaySelectVC.link.tableView.reloadData()
                    self.dismiss(animated: true, completion: nil)
                } else {
                    print("Document does not exist, no members to add!")
                }
            })
        }
        else {
            if alreadyExists(word: finalString) {
                ProgressHUD.colorAnimation = .red
                ProgressHUD.showFailed("Class already exists!")
                return
            }
            let currDoc = db.collection("classes").document(finalString)
            let data = ["name":"\(finalString)", "block":"\(selectedRow.Block.uppercased())","monday":MondaySwitch.isOn, "tuesday":TuesdaySwitch.isOn, "wednesday":WednesdaySwitch.isOn, "thursday":ThursdaySwitch.isOn, "friday":FridaySwitch.isOn] as [String : Any]
            currDoc.setData(data)
            DaySelectVC.link.Classes.append(selectedRow)
            DaySelectVC.link.filteredClasses = DaySelectVC.link.Classes
            DaySelectVC.link.tableView.reloadData()
            self.dismiss(animated: true, completion: nil)
        }
        
    }
}
