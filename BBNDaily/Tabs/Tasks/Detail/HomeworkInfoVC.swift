//
//  HomeworkInfoVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import ProgressHUD
import UIKit

// HQ-779: dead code - see the comment on detailedWorkVC.swift. Step two of the old
// wizard. Kept as a stub so the storyboard's outlet/action connections stay valid.
class HomeworkInfoVC: TextFieldVC {
    static var link: WorkVC!
    @IBOutlet weak var TextField: UITextField!
    @IBAction func pressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
