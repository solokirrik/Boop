//
//  PreferencesTabViewController.swift
//  Boop
//
//  Created by Ivan on 11/2/19.
//

import Cocoa

class PreferencesTabViewController: NSTabViewController {

    /// Every pane gets the same size, so the window doesn't jump when switching tabs.
    static let paneSize = NSSize(width: 560, height: 240)

    override func viewDidLoad() {
        super.viewDidLoad()
        tabViewItems.forEach(applyPaneSize)
    }

    // Panes loaded from the storyboard reset their size to the view's frame; set it again before showing
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem { applyPaneSize(item) }
        super.tabView(tabView, willSelect: tabViewItem)
    }

    private func applyPaneSize(_ item: NSTabViewItem) {
        item.viewController?.preferredContentSize = PreferencesTabViewController.paneSize
    }
}
