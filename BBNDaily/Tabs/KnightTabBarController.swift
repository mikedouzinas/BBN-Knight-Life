//
//  KnightTabBarController.swift
//  BBNDaily
//

import UIKit
import BubbleTabBar

/// The app's tab bar, which picks its own look based on what the OS can do.
///
/// On iOS 26 and later the system draws a Liquid Glass tab bar. BubbleTabBar (0.9.0, last
/// touched in 2018) installs itself by swapping UITabBarController's internal bar through KVC:
///
///     self.setValue(BubbleTabBar(), forKey: "tabBar")
///
/// That swap replaces the inner bar but not the system's Liquid Glass container, so on iOS 26
/// both are drawn and they sit on top of each other.
///
/// So: on iOS 26 and later this stays a plain UITabBarController and gets Liquid Glass for
/// free. On anything older it installs the bubble bar, so those users keep the look the app
/// has always had rather than losing it to a version check.
///
/// BubbleTabBarController's implementation is inlined here rather than subclassed, because a
/// Swift subclass cannot decline its superclass's viewDidLoad, and that viewDidLoad is exactly
/// where the unconditional swap happens.
class KnightTabBarController: UITabBarController {

    /// Whether to install the custom bubble bar. False on iOS 26+, where the system bar is the
    /// one the OS expects to manage and is better than what a 2018 pod can draw.
    private lazy var usesBubbleBar: Bool = {
        if #available(iOS 26.0, *) { return false }
        return true
    }()

    private let bubbleBarHeight: CGFloat = 74

    override func viewDidLoad() {
        super.viewDidLoad()
        guard usesBubbleBar else { return }
        setValue(BubbleTabBar(), forKey: "tabBar")
    }

    /// BubbleTabBar reports taps by calling this directly from its own button handler rather
    /// than through UIKit's normal tab bar machinery, so nothing switches the view controller
    /// unless we do it here.
    ///
    /// Deliberately does NOT branch on the OS and does NOT call super. Selecting the index is
    /// exactly what UITabBarController does itself, so it is correct on both paths: on iOS 26
    /// either UIKit never routes through here, in which case this is dead, or it does, in which
    /// case this does the right thing.
    ///
    /// An earlier version called `super.tabBar(tabBar, didSelect: item)` on the iOS 26 path and
    /// made every tab dead, crashing on Settings. UITabBarController conforms to UITabBarDelegate
    /// but implements it privately, so the call compiles against the protocol and finds no
    /// superclass implementation at runtime.
    ///
    /// The bubble bar keeps its own highlight in step through its `selectedItem` observer, so
    /// there is no need to tell it which item is selected. That is also not possible from here:
    /// its `select(itemAt:animated:)` is internal to the BubbleTabBar module.
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let index = tabBar.items?.firstIndex(of: item),
              index != selectedIndex else { return }
        selectedIndex = index
    }

    /// The bubble bar is taller than a system bar and has to be positioned by hand. On iOS 26
    /// the system owns the frame, so leave it alone.
    private func updateTabBarFrame() {
        guard usesBubbleBar else { return }
        let height = bubbleBarHeight + view.safeAreaInsets.bottom
        var frame = tabBar.frame
        frame.size.height = height
        frame.origin.y = view.frame.size.height - height
        tabBar.frame = frame
        tabBar.setNeedsLayout()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateTabBarFrame()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTabBarFrame()
    }
}
