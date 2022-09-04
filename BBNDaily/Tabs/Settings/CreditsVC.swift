//
//  CreditsVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class CreditsVC: UIViewController {
    @IBAction func close(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func openSheet(_ sender: Any) {
        if let url = URL(string: "https://docs.google.com/spreadsheets/d/1A1CLxugRIGmxIV595mbiR6noLdw4ShuxAKe-tjxATCc/edit?usp=sharing") {
            UIApplication.shared.open(url)
        }
    }
    @IBAction func openLibraries(_ sender: Any) {
        self.performSegue(withIdentifier: "OpenSource", sender: nil)
    }
    @IBAction func openPrivacy(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "LunchMenuVC") as? LunchMenuVC
        guard let vc = vc else {
            return
        }
        vc.urlstring = "http://www.termsfeed.com/live/7f2346ad-40d8-4b3c-8764-6e02aae213be"
        show(vc, sender: nil)
    }
}
