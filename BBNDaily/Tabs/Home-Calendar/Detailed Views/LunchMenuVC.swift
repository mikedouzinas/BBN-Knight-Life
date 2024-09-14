//
//  LunchMenuVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import ProgressHUD
import UIKit
import WebKit

import Firebase

class LunchMenuVC: CustomLoader, WKNavigationDelegate {
    static var week = ""
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    var urlstring = "http://docs.google.com/document/d/1QL-uIHSCOC5oZV3tOthRAuGEjmDjGIl-hlMdzcrpwIk/edit?usp=sharing"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let db = Firestore.firestore()
//        print("getting lunch menu")
        db.collection("schedules").document("menus").getDocument(completion: {(snap, err) in
            if (err != nil) {
                self.navigationController?.popViewController(animated: true)
                ProgressHUD.failed("Failed to find lunch schedule")
            } else {
                let menuUrl = snap?.data()?[LunchMenuVC.week] as? String ?? ""
                guard let url = URL(string: menuUrl) else {
                    // Exit the view
                    self.navigationController?.popViewController(animated: true)
                    // Say "Unable to get menu"
                    ProgressHUD.failed("Menu not available")
                    return
                }
                
                self.webView.backgroundColor = UIColor.white
                self.view.addSubview(self.webView)
                self.webView.frame = self.view.bounds
                self.webView.navigationDelegate = self
                self.webView.load(URLRequest(url: url))
                self.showLoaderView()
                self.view.backgroundColor = UIColor.white
            }
        })
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.revealViewController()?.gestureEnabled = false
    }
}
