//
//  InterfaceController.swift
//  BBNDailyWatchApp WatchKit Extension
//
//  Created by Mike Veson on 5/9/22.
//

import WatchKit
import Foundation
import WatchConnectivity

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("received data: \(message)")
        if let watchClasses = message["classes"] as? [WatchClass] { //**7.1
            
            ClassesTable.setNumberOfRows(watchClasses.count, withRowType: "ClassCell")
            var x = 0
            for y in watchClasses {
                let row = ClassesTable.rowController(at: x) as! ClassController
                row.TitleLabel.setText(y.Title)
                row.StartTimeLabel.setText(y.StartTime)
                row.EndTimeLabel.setText(y.EndTime)
                x+=1
            }
        }
        else {
            print("data did not work")
        }
    }
    
    @IBOutlet weak var ClassesTable: WKInterfaceTable!
    let session = WCSession.default
    
    override func awake(withContext context: Any?) {
        // Store an array and a date, and if the date is not equal to today's date, say you need to open the app to reload
        super.awake(withContext: context)
        ClassesTable.setNumberOfRows(1, withRowType: "ClassCell")
        let row = ClassesTable.rowController(at: 0) as! ClassController
        row.TitleLabel.setText("Open iphone app to update")
        row.StartTimeLabel.setText("--")
        row.EndTimeLabel.setText("--")
        
        session.delegate = self
        session.activate()
    }
    
    override func willActivate() {
        super.willActivate()
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        super.didDeactivate()
        // This method is called when watch view controller is no longer visible
    }
    
}
struct WatchClass {
    let Title: String
    let StartTime: String
    let EndTime: String
}

class ClassController: NSObject {
    @IBOutlet var TitleLabel: WKInterfaceLabel!
    @IBOutlet var StartTimeLabel: WKInterfaceLabel!
    @IBOutlet var EndTimeLabel: WKInterfaceLabel!
}

//                let classes = [WatchClass(Title: "Free", StartTime: "8:15 AM", EndTime: "9:00 AM"),WatchClass(Title: "Free", StartTime: "9:05 AM", EndTime: "9:50 AM"),WatchClass(Title: "Wellness Break", StartTime: "9:55 AM", EndTime: "10:15 AM"),WatchClass(Title: "Spanish", StartTime: "10:20 AM", EndTime: "11:25 AM"),WatchClass(Title: "Honors Physics", StartTime: "11:30 AM", EndTime: "12:15 PM"),WatchClass(Title: "Lunch", StartTime: "12:20 PM", EndTime: "12:45 PM"),WatchClass(Title: "US History", StartTime: "12:50 PM", EndTime: "1:55 PM"),WatchClass(Title: "Advisory", StartTime: "2:00 PM", EndTime: "2:35 PM"),WatchClass(Title: "Dynamic Duos", StartTime: "2:40 PM", EndTime: "3:25 PM")]


//        if let userDefaults = UserDefaults(suiteName: "group.bbncache") {
//            let currDate = userDefaults.string(forKey: "Date")
//            let formatter2 = DateFormatter()
//            formatter2.dateFormat = "yyyy-MM-dd"
//            formatter2.dateStyle = .short
//            let date = formatter2.string(from: Date())
//            print("dates: \(date) and \(currDate ?? "empty")")
//            if date != currDate {
//
//            }
//            else {
//                let titles = (userDefaults.array(forKey: "Titles") as? [String]) ?? [String]()
//
//                let startAndEndTimes = (userDefaults.array(forKey: "StartAndEndTimes") as? [String]) ?? [String]()
//
//                ClassesTable.setNumberOfRows(titles.count, withRowType: "ClassCell")
//                var x = 0
//                for title in titles {
//                    let row = ClassesTable.rowController(at: x) as! ClassController
//                    row.TitleLabel.setText(title)
//                    // set these to the correct values by splitting them in half
//                    let startAndEndTime = startAndEndTimes[x]
//                    let arr = startAndEndTime.components(separatedBy: "~")
//
//                    row.StartTimeLabel.setText("\(arr[0])")
//                    row.EndTimeLabel.setText("\(arr[1])")
//                    x+=1
//                }
//            }
//        }
