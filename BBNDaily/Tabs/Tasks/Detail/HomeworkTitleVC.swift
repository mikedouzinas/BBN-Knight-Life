//
//  HomeworkTitleVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import ProgressHUD

// HQ-779: dead code - see the comment on detailedWorkVC.swift. This was step one of the
// old freeform "add a task" wizard (WorkVC.newHomework no longer exists), and nothing
// segues to "newhomework" anymore. Kept as a stub so the storyboard's outlet/action
// connections stay valid.
class HomeworkTitleVC: TextFieldVC {
    static var link: WorkVC!
    @IBOutlet weak var TextField: UITextField!
    @IBAction func pressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
