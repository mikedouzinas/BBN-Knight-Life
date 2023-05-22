//
//  VanguardVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.

import UIKit
import GoogleSignIn
import Firebase
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit

class PublicationVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        webview.translatesAutoresizingMaskIntoConstraints = false
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    public var urlString = "https://vanguard.bbns.org/"
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
class VanguardVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString = "https://vanguard.bbns.org/"
        super.viewDidLoad()
        self.title = "The Vanguard"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}

class SpectatorVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString = "https://www.spectatorbbn.org/"
        super.viewDidLoad()
        self.title = "The Spectator"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}

class BenchwarmerVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString =  "https://bbnbenchwarmer.org/"
        super.viewDidLoad()
        self.title = "The Benchwarmer"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}

class CHASMVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString =  "https://bbnchasm.com/"
        super.viewDidLoad()
        self.title = "CHASM"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}

class POVVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString =  "https://pov.bbns.org/"
        super.viewDidLoad()
        self.title = "POV"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}

class MerchStoreVC: PublicationVC {
    @IBOutlet weak var sideMenuBtn: UIBarButtonItem!
    override func viewDidLoad() {
        self.urlString =  "https://www.amerasport.com/Buckingham-Browne-Nichols-BBN-BBN/departments/1029/"
        super.viewDidLoad()
        self.title = "BB&N Merchandise"
        sideMenuBtn.target = revealViewController()
        sideMenuBtn.action = #selector(revealViewController()?.revealSideMenu)
    }
}
