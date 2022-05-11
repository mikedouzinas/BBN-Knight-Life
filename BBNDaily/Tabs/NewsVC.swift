//
//  NewsVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 9/12/21.
//

import UIKit
import GoogleSignIn
import ProgressHUD
import InitialsImageView
import SafariServices
import FSCalendar
import WebKit

class LatestNewsVC: CustomLoader, WKNavigationDelegate {
    private let webView: WKWebView = {
        let webview = WKWebView(frame: .zero)
        return webview
    }()
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoaderView()
    }
    //    https://www.bbns.org/news-events/latest-news-from-bbn
    let urlString = "https://www.bbns.org/news-events/latest-news-from-bbn"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        webView.backgroundColor = UIColor.white
        view.addSubview(webView)
        webView.frame = view.bounds
        webView.navigationDelegate = self
        guard let url = URL(string: urlString) else {
            return
        }
        webView.load(URLRequest(url: url))
        showLoaderView()
    }
}

// future implementation, doesnt do anything yet
class AnnouncementsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return announcements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AnnouncementTableViewCell.identifier, for: indexPath) as? AnnouncementTableViewCell else {
            fatalError()
        }
        cell.backgroundColor = UIColor(named: "background")
        cell.configure(with: announcements[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }
    var announcements = [Announcement]()
    private let tableView: UITableView = {
        let tb = UITableView(frame: .zero)
        tb.backgroundColor = UIColor(named: "background")
        tb.register(AnnouncementTableViewCell.self, forCellReuseIdentifier: AnnouncementTableViewCell.identifier)
        return tb
    }()
    func configureTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.frame = view.bounds
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.backgroundColor = UIColor(named: "background")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
    }
}
struct Announcement {
    let Title: String
    let Date: String
    let timeframe: String?
    let location: String?
    let rightIndicator: Bool
}

class AnnouncementTableViewCell: UITableViewCell {
    static let identifier = "AnnouncementTableViewCell"
    
    private let newsTitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let subtitleLabel: UILabel = {
        let label = UILabel ()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    } ()
    private let newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 6
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(named: "lightGray")
        imageView.contentMode = .scaleAspectFill
        return imageView
    } ()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(newsTitleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(newsImageView)
        contentView.backgroundColor = UIColor(named: "background")
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        newsTitleLabel.frame = CGRect(x: 10, y: 0, width: contentView.frame.size.width - 170, height: 70)
        subtitleLabel.frame = CGRect(x: 10, y: 70, width: contentView.frame.size.width - 170, height: contentView.frame.size.height/2)
        newsImageView.frame = CGRect(x: contentView.frame.size.width-150, y: 5, width: 140, height: contentView.frame.size.height-10)
    }
    override func prepareForReuse(){
        super.prepareForReuse()
    }
    func configure(with viewModel: Announcement){
        newsTitleLabel.text = viewModel.Title
        subtitleLabel.text = viewModel.location ?? ""
        
    }
}
