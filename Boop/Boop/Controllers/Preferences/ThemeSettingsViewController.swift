//
//  ThemeSettingsViewController.swift
//  Boop
//
//  Created by Ivan on 6/18/20.
//

import Foundation
import Cocoa

enum BoopColorScheme: Int {
    case system
    case light
    case dark
}

class ThemeSettingsViewController: NSViewController {
    static let userPreferencesSchemeKey = "boopColorScheme"
    
    static func applyTheme() {
        switch BoopColorScheme(rawValue: UserDefaults.standard.integer(forKey: "boopColorScheme")) {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = view.fittingSize
    }
    @IBAction func didChangeColorTheme(_ sender: Any) {
        ThemeSettingsViewController.applyTheme()
    }

    @IBAction func didChangeTransparency(_ sender: Any) {
        WindowTransparency.didChange()
    }
}

/// "Window Transparency" setting: Off, 10%, 20% or 30% of the editor background shows
/// the blurred desktop behind the window. Off when "Reduce transparency" is on.
enum WindowTransparency {
    static let userPreferencesKey = "boopWindowTransparency"
    static let didChangeNotification = Notification.Name("BoopWindowTransparencyDidChange")

    /// 0, 0.1, 0.2 or 0.3
    static var level: CGFloat {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else { return 0 }
        let index = min(max(UserDefaults.standard.integer(forKey: userPreferencesKey), 0), 3)
        return CGFloat(index) / 10
    }

    static func didChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Follow the system "Reduce transparency" switch while the app runs.
    static func observeAccessibility() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { _ in didChange() }
    }
}
