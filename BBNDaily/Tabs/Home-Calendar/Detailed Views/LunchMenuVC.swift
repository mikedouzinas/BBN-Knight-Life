//
//  LunchMenuVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import WebKit

class LunchMenuVC: CustomLoader, WKNavigationDelegate {
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
        webView.backgroundColor = UIColor.white
        view.addSubview(webView)
        webView.frame = view.bounds
        webView.navigationDelegate = self
        guard let url = URL(string: urlstring) else {
            return
        }
        webView.load(URLRequest(url: url))
        showLoaderView()
        view.backgroundColor = UIColor.white
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.revealViewController()?.gestureEnabled = false
    }
}
