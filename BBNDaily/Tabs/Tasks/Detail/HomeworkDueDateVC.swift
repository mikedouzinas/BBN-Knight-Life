//
//  HomeworkDueDateVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import Firebase
import UIKit

// HQ-779: dead code - see the comment on detailedWorkVC.swift. Final step of the old
// wizard, the one that actually wrote a task. Kept as a stub so the storyboard's
// outlet/action connections stay valid.
class HomeworkDueDateVC: TextFieldVC {
    @IBOutlet weak var datePicker: UIDatePicker!
    static var link: WorkVC!
    @IBAction func pressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
