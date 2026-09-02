//
//  detailedWorkVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import Firebase

// HQ-779: dead code as of the Tasks rebuild - this screen showed/deleted an entry from
// the old freeform task list, which no longer exists (WorkVC.tasks, .selectedTask,
// .sortTasks() are all gone). Nothing segues here anymore ("largeWork" is unused), so
// this is unreachable. Kept as a harmless stub, not deleted outright, because the
// storyboard scene and its outlet/action connections still reference this class name -
// removing the file without also removing that scene (a separate, lower-risk edit to
// do directly in Interface Builder rather than by hand here) would break the storyboard.
class detailedWorkVC: UIViewController {
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var detailedTextView: UITextView!
    @IBAction func removeTask(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
