//
//  detailedWorkVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class detailedWorkVC: UIViewController {
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var detailedTextView: UITextView!
    static var link: WorkVC!
    @IBAction func removeTask(_ sender: Any) {
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
//        print("\(detailedWorkVC.link.selectedTask.dueDate)")
        dateLabel.text = "Due \(detailedWorkVC.link.selectedTask.dueDate.stringDateFromMultipleFormats(preferredFormat: 7) ?? "")"

        detailedTextView.text = "\(detailedWorkVC.link.selectedTask.description)"
        self.title = "\(detailedWorkVC.link.selectedTask.title)"
    }
}
