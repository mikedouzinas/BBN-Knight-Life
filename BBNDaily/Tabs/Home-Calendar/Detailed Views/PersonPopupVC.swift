//
//  PersonPopupVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

class PersonPopupVC: UIViewController {
    public let textView = UITextView()
    override func viewDidLoad() {
        textView.frame = view.bounds
        view.addSubview(textView)
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 20, weight: .regular)
        textView.textColor = UIColor(named: "inverse")
        textView.backgroundColor = UIColor(named: "background")
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.revealViewController()?.gestureEnabled = false
    }
}
