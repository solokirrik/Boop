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

/// Settings > Colors: color scheme, window transparency and its background style.
class ThemeSettingsViewController: NSViewController {
    static let userPreferencesSchemeKey = "boopColorScheme"

    static func applyTheme() {
        switch BoopColorScheme(rawValue: UserDefaults.standard.integer(forKey: userPreferencesSchemeKey)) {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }

    private let schemeControl = NSSegmentedControl(labels: ["Default", "Light", "Dark"], trackingMode: .selectOne, target: nil, action: nil)
    private let backgroundControl = NSSegmentedControl(labels: ["Frosted", "Glass", "Clear Glass"], trackingMode: .selectOne, target: nil, action: nil)
    private let transparencySlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let transparencyValue = NSTextField(labelWithString: "")

    override func viewDidLoad() {
        super.viewDidLoad()

        schemeControl.target = self
        schemeControl.action = #selector(didChangeColorTheme(_:))
        schemeControl.toolTip = "Default follows the system appearance"

        backgroundControl.target = self
        backgroundControl.action = #selector(didChangeBackground(_:))
        backgroundControl.toolTip = "How what's behind the window shows through"

        transparencySlider.numberOfTickMarks = WindowTransparency.percentages.count
        transparencySlider.allowsTickMarkValuesOnly = true
        transparencySlider.isContinuous = true
        transparencySlider.target = self
        transparencySlider.action = #selector(didChangeTransparency(_:))
        transparencySlider.widthAnchor.constraint(equalToConstant: 200).isActive = true

        transparencyValue.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        transparencyValue.textColor = .secondaryLabelColor
        transparencyValue.alignment = .right
        transparencyValue.widthAnchor.constraint(equalToConstant: 40).isActive = true

        let sliderRow = NSStackView(views: [transparencySlider, transparencyValue])
        sliderRow.spacing = 8

        let grid = NSGridView(views: [
            [label("Color Scheme:"), schemeControl],
            [label("Transparency:"), sliderRow],
            [label("Background:"), backgroundControl]
        ])
        grid.rowSpacing = 14
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 1).yPlacement = .center
        grid.row(at: 1).rowAlignment = .none
        grid.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -28),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        return field
    }

    /// Shows the saved values.
    private func refresh() {
        let defaults = UserDefaults.standard
        schemeControl.selectedSegment = defaults.integer(forKey: ThemeSettingsViewController.userPreferencesSchemeKey)
        backgroundControl.selectedSegment = WindowTransparency.style.rawValue
        transparencySlider.integerValue = WindowTransparency.percent
        updateTransparencyUI()
    }

    private func updateTransparencyUI() {
        transparencyValue.stringValue = "\(transparencySlider.integerValue)%"
        // The style only matters when the window is see-through
        backgroundControl.isEnabled = transparencySlider.integerValue > 0
    }

    @IBAction func didChangeColorTheme(_ sender: Any) {
        UserDefaults.standard.set(schemeControl.selectedSegment, forKey: ThemeSettingsViewController.userPreferencesSchemeKey)
        ThemeSettingsViewController.applyTheme()
    }

    @IBAction func didChangeBackground(_ sender: Any) {
        UserDefaults.standard.set(backgroundControl.selectedSegment, forKey: WindowTransparency.styleUserPreferencesKey)
        WindowTransparency.didChange()
    }

    @IBAction func didChangeTransparency(_ sender: Any) {
        let percent = WindowTransparency.snap(transparencySlider.integerValue)
        guard percent != WindowTransparency.percent else {
            updateTransparencyUI()
            return
        }
        UserDefaults.standard.set(percent, forKey: WindowTransparency.userPreferencesKey)
        updateTransparencyUI()
        WindowTransparency.didChange()
    }
}

/// Window transparency: 0–100% of the editor background shows what's behind the
/// window, in one of three styles. Off when "Reduce transparency" is on.
enum WindowTransparency {
    static let userPreferencesKey = "boopWindowTransparencyPercent"
    static let styleUserPreferencesKey = "boopWindowBackdrop"
    static let didChangeNotification = Notification.Name("BoopWindowTransparencyDidChange")

    /// Slider stops
    static let percentages = [0, 20, 40, 60, 80, 100]

    /// Older builds stored 0…5 meaning 0–50%
    private static let legacyUserPreferencesKey = "boopWindowTransparency"

    /// What's behind the window looks like this (all public APIs).
    enum Style: Int {
        case frosted      // strong system blur: only color comes through
        case glass        // Liquid Glass, lighter blur: shapes stay recognizable (macOS 26+)
        case clearGlass   // Liquid Glass "clear": see-through with a glass sheen (macOS 26+)
    }

    /// The saved setting, 0–100 in steps of 20.
    static var percent: Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: userPreferencesKey) == nil,
           defaults.object(forKey: legacyUserPreferencesKey) != nil {
            return snap(defaults.integer(forKey: legacyUserPreferencesKey) * 10)
        }
        return snap(defaults.integer(forKey: userPreferencesKey))
    }

    /// 0…1, honoring "Reduce transparency"
    static var level: CGFloat {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else { return 0 }
        return CGFloat(percent) / 100
    }

    static var style: Style {
        let raw = UserDefaults.standard.integer(forKey: styleUserPreferencesKey)
        // An older "Clear" option (3) maps to the closest remaining style
        return Style(rawValue: min(max(raw, 0), Style.clearGlass.rawValue)) ?? .frosted
    }

    /// Nearest slider stop.
    static func snap(_ value: Int) -> Int {
        return percentages.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0
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
