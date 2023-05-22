//
//  WelcomeVC.swift
//  BBNDaily
//
//  Created by Mike Veson on 4/6/23.
//

import Foundation
import UIKit

// This class is called when the user's classes are not configured.
// It should show well-designed user oriented welcome pages that show more than just classes-- clubs, locker nums, etc.

class WelcomeVC: UIViewController {
    private var currentPage: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "blue")
        setupPages()
    }
    
    private func setupPages() {
        switch currentPage {
        case 0:
            setupWelcomePage()
        case 1:
            setupClassSelectionPage()
        case 2:
            setupLunchSelectionPage()
        default:
            break
        }
    }
    
    private func setupWelcomePage() {
        // Create an UIImageView for the image
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: view.bounds.width * 0.5, height: view.bounds.height * 0.25))
        imageView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height * 0.4)
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "logo")
        view.addSubview(imageView)

        // Create a welcome message label
        let welcomeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height * 0.2))
        welcomeLabel.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height * 0.6)
        welcomeLabel.textAlignment = .center
        welcomeLabel.textColor = UIColor(named: "white")
        welcomeLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        welcomeLabel.text = "Welcome to Knight Life!"
        view.addSubview(welcomeLabel)
        
        // Call animateWelcomePage with a 1-second delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIView.animate(withDuration: 1, animations: {
                welcomeLabel.center.y -= self.view.bounds.height * 0.4
                welcomeLabel.alpha = 0
                imageView.alpha = 0
            }, completion: { _ in
                self.nextPage()
            })
        }
    }
    
    @objc private func nextPage() {
        // Fade-out animation before showing the next page
        UIView.animate(withDuration: 0.5, animations: {
            for subview in self.view.subviews {
                subview.alpha = 0
            }
        }, completion: { _ in
            // Remove all subviews from the current page
            for subview in self.view.subviews {
                subview.removeFromSuperview()
            }
            
            // Reset the view's alpha and proceed to the next page
            self.view.alpha = 1
            self.currentPage += 1
            self.setupPages()
        })
    }
    func getClassesFor(block: String) -> [String] {
        switch block {
        case "A":
            return ["Geo~Mr. Fidler~A~135"]
        case "B":
            return ["Geo~Mr. Fidler~B~135", "Geo~Mr. Fidler~A~135"]
        case "C":
            return ["Geo~Mr. Fidler~C~135", "Geo~Mr. Fidler~A~135", "Geo~Mr. Fidler~A~135"]
        case "D":
            return ["Geo~Mr. Fidler~D~135", "Geo~Mr. Fidler~A~135", "Geo~Mr. Fidler~A~135"]
        case "E":
            return ["Geo~Mr. Fidler~E~135", "Geo~Mr. Fidler~A~135", "Geo~Mr. Fidler~A~135"]
        case "F":
            return ["Geo~Mr. Fidler~F~135", "Geo~Mr. Fidler~A~135", "Geo~Mr. Fidler~A~135"]
        case "G":
            return ["Geo~Mr. Fidler~G~135", "Geo~Mr. Fidler~A~135", "Geo~Mr. Fidler~A~135"]
        default:
            return [String]()
        }
    }
    private func setupClassSelectionPage() {
        let titles = ["A", "B", "C", "D", "E", "F", "G"]
        var options = [[String]]()
        for (index, _) in titles.enumerated() {
            options.append(getClassesFor(block: titles[index]))
        }
        let classSelectionView = SelectionView(frame: view.bounds, selectionType: .classSelection, titles: titles, options: options)
        classSelectionView.delegate = self
        view.addSubview(classSelectionView)
    }

    private func setupLunchSelectionPage() {
        let titles = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        let options = Array(repeating: ["Lunch 1", "Lunch 2"], count: titles.count)
        let lunchSelectionView = SelectionView(frame: view.bounds, selectionType: .lunchSelection, titles: titles, options: options)
        lunchSelectionView.delegate = self
        view.addSubview(lunchSelectionView)
    }
}

extension WelcomeVC: SelectionViewDelegate {
    func selectionCompleted(for selectionType: SelectionType) {
        switch selectionType {
        case .classSelection:
            nextPage()
        case .lunchSelection:
            // Perform the next given action in code after lunch selection is complete
            break
        }
    }
}
