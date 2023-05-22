//
//  SideMenuVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 6/17/22.
//

import Foundation
import UIKit
import SideMenu
import Firebase
import ProgressHUD

class MainViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.revealViewController()?.gestureEnabled = true
//        HomeViewController.name = "Mike Veson" // new name
//        HomeViewController.profilePhoto.setImageForName(HomeViewController.name, backgroundColor: UIColor(named: "orange"), circular: false, textAttributes: nil, gradient: true)
    }
    private var sideMenuViewController: SideMenuViewController!
    private var sideMenuShadowView: UIView!
    private var sideMenuRevealWidth: CGFloat = 260
    private let paddingForRotation: CGFloat = 150
    private var isExpanded: Bool = false
    private var draggingIsEnabled: Bool = false
    private var panBaseLocation: CGFloat = 0.0
    
    // Expand/Collapse the side menu by changing trailing's constant
    private var sideMenuTrailingConstraint: NSLayoutConstraint!
    
    private var revealSideMenuOnTop: Bool = true
    
    var gestureEnabled: Bool = true
    
    var tabImage: UIImage? {
        return UIImage(named: "tab-home")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(named: "backgroundCol")
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.scrollEdgeAppearance?.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        // Shadow Background View
        self.sideMenuShadowView = UIView(frame: self.view.bounds)
        self.sideMenuShadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sideMenuShadowView.backgroundColor = .black
        self.sideMenuShadowView.alpha = 0.0
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(TapGestureRecognizer))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGestureRecognizer)
        if self.revealSideMenuOnTop {
            view.insertSubview(self.sideMenuShadowView, at: 1)
        }
        
        // Side Menu
        let strybrd = UIStoryboard(name: "Main", bundle: nil)
        guard let sdmenuvc = strybrd.instantiateViewController(withIdentifier: "SideMenuID") as? SideMenuViewController else {
            print("")
            return
        }
        self.sideMenuViewController = sdmenuvc
       // self.sideMenuViewController = strybrd.instantiateViewController(withIdentifier: "SideMenuID") as? SideMenuViewController
        
        self.sideMenuViewController.defaultHighlightedCell = 0 // Default Highlighted Cell
        self.sideMenuViewController.delegate = self
        view.insertSubview(self.sideMenuViewController!.view, at: self.revealSideMenuOnTop ? 2 : 0)
        addChild(self.sideMenuViewController!)
        self.sideMenuViewController!.didMove(toParent: self)
        
        // Side Menu AutoLayout
        self.sideMenuViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        if self.revealSideMenuOnTop {
            self.sideMenuTrailingConstraint = self.sideMenuViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.sideMenuRevealWidth - self.paddingForRotation)
            self.sideMenuTrailingConstraint.isActive = true
        }
        NSLayoutConstraint.activate([
            self.sideMenuViewController.view.widthAnchor.constraint(equalToConstant: self.sideMenuRevealWidth),
            self.sideMenuViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            self.sideMenuViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
        ])
        
        // Side Menu Gestures
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
        
        // Default Main View Controller
        showViewController(viewController: UINavigationController.self, storyboardId: "ScheduleNavID")
    }
    
    // Keep the state of the side menu (expanded or collapse) in rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            if self.revealSideMenuOnTop {
                self.sideMenuTrailingConstraint.constant = self.isExpanded ? 0 : (-self.sideMenuRevealWidth - self.paddingForRotation)
            }
        }
    }
    
    func animateShadow(targetPosition: CGFloat) {
        UIView.animate(withDuration: 0.5) {
            // When targetPosition is 0, which means side menu is expanded, the shadow opacity is 0.6
            self.sideMenuShadowView.alpha = (targetPosition == 0) ? 0.6 : 0.0
        }
    }
    
    // Call this Button Action from the View Controller you want to Expand/Collapse when you tap a button
    @IBAction open func revealSideMenu() {
        self.sideMenuState(expanded: self.isExpanded ? false : true)
    }
    
    func sideMenuState(expanded: Bool) {
        if expanded {
            self.animateSideMenu(targetPosition: self.revealSideMenuOnTop ? 0 : self.sideMenuRevealWidth) { _ in
                self.isExpanded = true
            }
            // Animate Shadow (Fade In)
            UIView.animate(withDuration: 0.5) { self.sideMenuShadowView.alpha = 0.6 }
        }
        else {
            self.animateSideMenu(targetPosition: self.revealSideMenuOnTop ? (-self.sideMenuRevealWidth - self.paddingForRotation) : 0) { _ in
                self.isExpanded = false
            }
            // Animate Shadow (Fade Out)
            UIView.animate(withDuration: 0.5) { self.sideMenuShadowView.alpha = 0.0 }
        }
    }
    func animateSideMenu(targetPosition: CGFloat, completion: @escaping (Bool) -> ()) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            if self.revealSideMenuOnTop {
                self.sideMenuTrailingConstraint.constant = targetPosition
                self.view.layoutIfNeeded()
            }
            else {
                self.view.subviews[1].frame.origin.x = targetPosition
            }
        }, completion: completion)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
//MARK: Side Menu
extension MainViewController: SideMenuViewControllerDelegate {
    func selectedCell(_ row: Int) {
        CalendarVC.hasPressedSideMenu = true
        switch row {
        case 0:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "ScheduleNavID")
        case 1:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "VanguardNavID")
        case 2:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "SpectatorNavID")
        case 3:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "BenchwarmerNavID")
        case 4:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "CHASMNavID")
        case 5:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "POVNavID")
        case 6:
            self.showViewController(viewController: UINavigationController.self, storyboardId: "MerchNavID")
        default:
            break
        }
        // Collapse side menu with animation
        DispatchQueue.main.async { self.sideMenuState(expanded: false) }
    }
    func showViewController<T: UIViewController>(viewController: T.Type, storyboardId: String) -> () {
        // Remove the previous View
        for subview in view.subviews {
            if subview.tag == 99 {
                subview.removeFromSuperview()
            }
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: storyboardId) as! T
        vc.view.tag = 99
        view.insertSubview(vc.view, at: self.revealSideMenuOnTop ? 0 : 1)
        addChild(vc)
        if !self.revealSideMenuOnTop {
            if isExpanded {
                vc.view.frame.origin.x = self.sideMenuRevealWidth
            }
            if self.sideMenuShadowView != nil {
                vc.view.addSubview(self.sideMenuShadowView)
            }
        }
        vc.didMove(toParent: self)
    }
}
extension MainViewController: UIGestureRecognizerDelegate {
    @objc public func TapGestureRecognizer(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            if self.isExpanded {
                self.sideMenuState(expanded: false)
            }
        }
    }
    // Close side menu when you tap on the shadow background view
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isDescendant(of: self.sideMenuViewController.view))! {
            return false
        }
        return true
    }
    // Dragging Side Menu
    @objc private func handlePanGesture(sender: UIPanGestureRecognizer) {
        guard gestureEnabled == true else { return }
        let position: CGFloat = sender.translation(in: self.view).x
        let velocity: CGFloat = sender.velocity(in: self.view).x
        switch sender.state {
        case .began:
            // If the user tries to expand the menu more than the reveal width, then cancel the pan gesture
            if velocity > 0, self.isExpanded {
                sender.state = .cancelled
            }
            
            // If the user swipes right but the side menu hasn't expanded yet, enable dragging
            if velocity > 0, !self.isExpanded {
                self.draggingIsEnabled = true
            }
            // If user swipes left and the side menu is already expanded, enable dragging
            else if velocity < 0, self.isExpanded {
                self.draggingIsEnabled = true
            }
            if self.draggingIsEnabled {
                // If swipe is fast, Expand/Collapse the side menu with animation instead of dragging
                let velocityThreshold: CGFloat = 550
                if abs(velocity) > velocityThreshold {
                    self.sideMenuState(expanded: self.isExpanded ? false : true)
                    self.draggingIsEnabled = false
                    return
                }
                
                if self.revealSideMenuOnTop {
                    self.panBaseLocation = 0.0
                    if self.isExpanded {
                        self.panBaseLocation = self.sideMenuRevealWidth
                    }
                }
            }
        case .changed:
            // Expand/Collapse side menu while dragging
            if self.draggingIsEnabled {
                if self.revealSideMenuOnTop {
                    // Show/Hide shadow background view while dragging
                    let xLocation: CGFloat = self.panBaseLocation + position
                    let percentage = (xLocation * 150 / self.sideMenuRevealWidth) / self.sideMenuRevealWidth
                    
                    let alpha = percentage >= 0.6 ? 0.6 : percentage
                    self.sideMenuShadowView.alpha = alpha
                    
                    // Move side menu while dragging
                    if xLocation <= self.sideMenuRevealWidth {
                        self.sideMenuTrailingConstraint.constant = xLocation - self.sideMenuRevealWidth
                    }
                }
                else {
                    if let recogView = sender.view?.subviews[1] {
                        // Show/Hide shadow background view while dragging
                        let percentage = (recogView.frame.origin.x * 150 / self.sideMenuRevealWidth) / self.sideMenuRevealWidth
                        
                        let alpha = percentage >= 0.6 ? 0.6 : percentage
                        self.sideMenuShadowView.alpha = alpha
                        
                        // Move side menu while dragging
                        if recogView.frame.origin.x <= self.sideMenuRevealWidth, recogView.frame.origin.x >= 0 {
                            recogView.frame.origin.x = recogView.frame.origin.x + position
                            sender.setTranslation(CGPoint.zero, in: view)
                        }
                    }
                }
            }
        case .ended:
            self.draggingIsEnabled = false
            // If the side menu is half Open/Close, then Expand/Collapse with animation
            if self.revealSideMenuOnTop {
                let movedMoreThanHalf = self.sideMenuTrailingConstraint.constant > -(self.sideMenuRevealWidth * 0.5)
                self.sideMenuState(expanded: movedMoreThanHalf)
            }
            else {
                if let recogView = sender.view?.subviews[1] {
                    let movedMoreThanHalf = recogView.frame.origin.x > self.sideMenuRevealWidth * 0.5
                    self.sideMenuState(expanded: movedMoreThanHalf)
                }
            }
        default:
            break
        }
    }
}
extension UIViewController {
    // With this extension you can access the MainViewController from the child view controllers.
    func revealViewController() -> MainViewController? {
        var viewController: UIViewController? = self
        if viewController != nil && viewController is MainViewController {
            return viewController! as? MainViewController
        }
        while (!(viewController is MainViewController) && viewController?.parent != nil) {
            viewController = viewController?.parent
        }
        if viewController is MainViewController {
            return viewController as? MainViewController
        }
        return nil
    }
}
protocol SideMenuViewControllerDelegate {
    func selectedCell(_ row: Int)
}

class SideMenuViewController: AuthVC {
    @IBOutlet weak var backview: UIView!
    @IBOutlet var userEmail: UILabel!
    @IBOutlet var userName: UILabel!
    @IBOutlet var signOutButton: UIButton!
    @IBOutlet var headerImageView: UIImageView!
    @IBOutlet var sideMenuTableView: UITableView!
    @IBOutlet var footerLabel: UILabel!
    var currentIndexPath = IndexPath(row: 0, section: 0)
    var delegate: SideMenuViewControllerDelegate?
    var defaultHighlightedCell: Int = 0
    var menu: [SideMenuModel] = [
        SideMenuModel(icon: UIImage(systemName: "calendar")!, title: "Schedule"),
        SideMenuModel(icon: UIImage(named: "vanguardLogo")!, title: "The Vanguard", textImage: UIImage(named: "vanguardTextLogo")),
        SideMenuModel(icon: UIImage(named: "spectatorLogo")!, title: "The Spectator", textImage: UIImage(named: "spectatorTextLogo")),
        SideMenuModel(icon: UIImage(named: "benchwarmerLogo")!, title: "The Benchwarmer", textImage: UIImage(named: "benchwarmerTextLogo")),
        SideMenuModel(icon: UIImage(systemName: "bonjour")!, title: "CHASM"),
        SideMenuModel(icon: UIImage(named: "POVLogo")!, title: "POV", textImage: UIImage(named: "povTextLogo")),
        SideMenuModel(icon: UIImage(systemName: "bag.circle.fill")!, title: "Merch Store")
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        // TableView
        self.sideMenuTableView.delegate = self
        self.sideMenuTableView.dataSource = self
        self.sideMenuTableView.backgroundColor = UIColor(named: "background")
        self.sideMenuTableView.separatorStyle = .none
        self.sideMenuTableView.isScrollEnabled = false
        self.sideMenuTableView.delaysContentTouches = false
        
//        backview.isUserInteractionEnabled = true
//        let guestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(profilePressed(_:)))
//        backview.addGestureRecognizer(guestureRecognizer)
        backview.layer.masksToBounds = true
        backview.layer.cornerRadius = 10
        backview.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
        userEmail.textColor = UIColor(named: "inverse")?.withAlphaComponent(0.7)
        backview.dropShadow()
        // Set Highlighted Cell
        DispatchQueue.main.async {
            let defaultRow = IndexPath(row: self.defaultHighlightedCell, section: 0)
            self.sideMenuTableView.selectRow(at: defaultRow, animated: false, scrollPosition: .none)
        }
        // Footer
        signOutButton.layer.masksToBounds = true
        signOutButton.layer.cornerRadius = 5
        signOutButton.backgroundColor = UIColor(named: "inverse")?.withAlphaComponent(0.1)
        signOutButton.setTitleColor(UIColor(named: "inverseBackgroundCol-OG"), for: .normal)
        signOutButton.dropShadow()
        self.headerImageView.layer.cornerRadius = 10
        self.headerImageView.layer.masksToBounds = true
        if ((LoginVC.blocks["googlePhoto"] ?? "") as! String) == "true" {
            setProfileImage(useGoogle: true, width: UInt(self.view.frame.width), completion: {_ in
                self.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
        else {
            setProfileImage(useGoogle: false, width: UInt(self.view.frame.width), completion: {_ in
                self.headerImageView.image = LoginVC.profilePhoto.image
            })
        }
        var userNameText = "\(LoginVC.fullName.capitalized)"
        if let index = userNameText.firstIndex(of: " ") {
            userNameText = "\(userNameText.prefix(upTo: index))"
        }
        
        self.userName.text = userNameText
        self.userEmail.text = "\(LoginVC.email)"
        // Register TableView Cell
        self.sideMenuTableView.register(SideMenuCell.nib, forCellReuseIdentifier: SideMenuCell.identifier)
        // Update TableView with the data
        self.sideMenuTableView.reloadData()
    }
    @objc func profilePressed(_ sender: Any) {
//        SettingsVC.ProfileLink = self
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SettingsNavID") as? UINavigationController
        guard let vc = vc else {
            return
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
//        self.performSegue(withIdentifier: "Profile", sender: nil)
        UIView.animate(withDuration: 0.2, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.backview.alpha = 0.2
        }) { (_) in
            UIView.animate(withDuration: 0.15, delay: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
                self.backview.alpha = 1
            }, completion: nil)
        }
    }
    @IBAction func signOut() {
        let refreshAlert = UIAlertController(title: "Sign Out", message: "Are you sure?", preferredStyle: .alert)
        refreshAlert.addAction(UIAlertAction(title: "Sign Out", style: .default, handler: { (action: UIAlertAction!) in
            self.signOutToken()
        }))
        refreshAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))
        present(refreshAlert, animated: true, completion: nil)
    }
    func getPostString(params:[String:Any]) -> String
    {
        var data = [String]()
        for(key, value) in params
        {
            data.append(key + "=\(value)")
        }
        return data.map { String($0) }.joined(separator: "&")
    }
    
}

extension SideMenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}
extension SideMenuViewController: UITableViewDataSource {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.revealViewController()?.gestureEnabled = true
        headerImageView.image = LoginVC.profilePhoto.image
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.menu.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SideMenuCell.identifier, for: indexPath) as? SideMenuCell else { fatalError("xib doesn't exist") }
        cell.iconImageView.image = self.menu[indexPath.row].icon
        if let textImg = self.menu[indexPath.row].textImage {
            cell.textImageView.image = textImg
            cell.titleLabel.text = ""
        }
        else {
            cell.titleLabel.text = self.menu[indexPath.row].title
            cell.textImageView.image = nil
        }
        cell.backgroundColor = UIColor(named: "background")
        cell.background.dropShadow()
        cell.titleLabel.textColor = UIColor(named: "inverse")
        cell.iconImageView.tintColor = UIColor(named: "inverse")
        cell.textImageView.tintColor = UIColor(named: "inverse")
        let myCustomSelectionColorView = UIView()
        if indexPath.row == 0 {
            cell.background.backgroundColor = UIColor(named: "inverse-light")
            cell.titleLabel.textColor = UIColor(named: "inverse")
            cell.iconImageView.tintColor = UIColor(named: "inverse")
        }
        cell.selectedBackgroundView = myCustomSelectionColorView
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        deselect(cell: tableView.cellForRow(at: currentIndexPath) as! SideMenuCell)
        select(cell: tableView.cellForRow(at: indexPath) as! SideMenuCell)
        currentIndexPath = indexPath
        self.delegate?.selectedCell(indexPath.row)
    }
    func deselect(cell: SideMenuCell) {
        cell.background.backgroundColor = .clear
//        cell.background.removeGradientBackground()
        cell.titleLabel.textColor = UIColor(named: "inverse")
        cell.iconImageView.tintColor = UIColor(named: "inverse")
        cell.textImageView.tintColor = UIColor(named: "inverse")
    }
    func select(cell: SideMenuCell) {
        cell.background.backgroundColor = UIColor(named: "inverse-light")
        cell.titleLabel.textColor = UIColor(named: "inverse")
        cell.iconImageView.tintColor = UIColor(named: "inverse")
        cell.textImageView.tintColor = UIColor(named: "inverse")
    }
}

class SideMenuCell: UITableViewCell {
    class var identifier: String { return String(describing: self) }
    class var nib: UINib { return UINib(nibName: identifier, bundle: nil) }
    @IBOutlet weak var background: UIView!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var textImageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = UIColor(named: "backgroundCol-low-alpha")
        self.background.backgroundColor = .clear
        self.background.layer.masksToBounds = true
        self.background.layer.cornerRadius = 5
        self.iconImageView.tintColor = UIColor(named: "inverseBackgroundCol")
        self.textImageView.tintColor = UIColor(named: "inverseBackgroundCol")
        self.titleLabel.textColor = UIColor(named: "inverseBackgroundCol")
    }
}
