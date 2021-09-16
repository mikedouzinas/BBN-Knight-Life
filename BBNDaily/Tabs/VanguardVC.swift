//
//  VanguardVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.
//

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit


class VanguardVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        webview.translatesAutoresizingMaskIntoConstraints = false
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    //    https://www.bbns.org/news-events/latest-news-from-bbn
    let urlString = "https://vanguard.bbns.org/category/on-campus/"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        webView.backgroundColor = UIColor.white
        view.addSubview(webView)
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        webView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webView.navigationDelegate = self
        guard let url = URL(string: urlString) else {
            return
        }
        webView.load(URLRequest(url: url))
        showLoaderView()
    }
}
