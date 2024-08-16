//
//  ThroughDateVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/23/22.
//

import Foundation
import UIKit
import ProgressHUD
import Firebase

class ThroughDateVC: UIViewController {
    var link: SecretScheduleVC!
    @IBAction func close () {
        dismiss(animated: true)
    }
    @IBAction func continueTask () {
        if startDatePicker.date < endDatePicker.date {
        showInputDialog(title: "Add reason",
                        subtitle: "Please enter the reason for the lack of school during this period.",
                        actionTitle: "Finish",
                        cancelTitle: "Cancel",
                        inputPlaceholder: "Summer break",
                        inputKeyboardType: .default, actionHandler:
                            { [self] (input:String?) in
            // upload
//            let date1 = startDatePicker.date
            let formatter2 = DateFormatter()
            formatter2.dateStyle = .full
            let date1 = formatter2.string(from: startDatePicker.date)
            let date2 = formatter2.string(from: endDatePicker.date)
            let finalString = "\(date1)-\(date2)"
            let reason = input ?? "Break"
            LoginVC.specialSchedules["\(finalString)"] = SpecialSchedule(specialSchedules: [block](), specialSchedulesL1: [block](), reason: reason, date: "\(date1)-\(date2)")
            let db = Firestore.firestore()
            let currDoc = db.collection("special-schedules").document("\(finalString)")
            currDoc.setData(["date":"\(finalString)", "reason":"\(reason)"])
            link.ScheduleCalendar.reloadData()
            dismiss(animated: true)
        })
        }
        else {
            ProgressHUD.colorAnimation = .red
            ProgressHUD.failed("The start date must precede the end date!")
        }
    }
    @IBOutlet var startDatePicker: UIDatePicker!
    @IBOutlet var endDatePicker: UIDatePicker!
}
