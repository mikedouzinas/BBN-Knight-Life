//
//  AboutUsVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit
import WebKit
import SafariServices

class AboutUsVC: CustomLoader, WKNavigationDelegate, UITableViewDataSource, UITableViewDelegate{
    @IBOutlet var sideMenuBtn: UIBarButtonItem!
    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.backgroundColor = UIColor(named: "background")
        table.register(AboutTableViewCell.self,
                       forCellReuseIdentifier: AboutTableViewCell.identifier)
        return table
    }()
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Open Source Libraries"
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Libraries Used"
        view.backgroundColor = UIColor(named: "background")
        tableView.tableFooterView = UIView(frame: .zero)
        setData()
        tableView.backgroundColor = UIColor (named: "background")
    }
    func setData() {
        view.addSubview(tableView)
        var libraries2 = [Library]()
        libraries2.append(Library(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk/blob/master/LICENSE"))
        libraries2.append(Library(name: "Google Sign In", url: "https://github.com/google/GoogleSignIn-iOS/blob/main/LICENSE"))
        libraries2.append(Library(name: "FS Calendar", url: "https://github.com/WenchaoD/FSCalendar/blob/master/LICENSE"))
        libraries2.append(Library(name: "ICONS8", url: "https://icons8.com/vue-static/landings/pricing/icons8-license.pdf"))
        libraries2.append(Library(name: "Progress HUD", url: "https://github.com/relatedcode/ProgressHUD/blob/master/LICENSE"))
        libraries2.append(Library(name: "Bubble Tab Bar", url: "https://github.com/Cuberto/bubble-icon-tabbar/blob/master/LICENSE"))
        libraries2.append(Library(name: "Initials ImageView", url: "https://github.com/bachonk/InitialsImageView/blob/master/LICENSE"))
        tableViewData.append(Libraries(libraries: libraries2))
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.delegate = self
    }
    var tableViewData = [Libraries]()
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewData[section].libraries.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let library = tableViewData[indexPath.section].libraries[indexPath.row]
        let vc = SFSafariViewController(url: URL(string: library.url)!)
        present(vc, animated: true)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.identifier,
                                                 for: indexPath) as! AboutTableViewCell
        cell.selectionStyle = .none
        cell.configure(with: tableViewData[indexPath.section].libraries[indexPath.row])
        return cell
    }
}
