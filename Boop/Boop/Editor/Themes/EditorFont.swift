//
//  EditorFont.swift
//  Boop
//
//  Created by Kirill on 11/17/26.
//

import Cocoa

/// The editor font, picked in Settings > Appearance and sized from the View menu.
/// Only monospaced families are offered, so tab stops and columns line up.
enum EditorFont {
    static let familyUserPreferencesKey = "boopEditorFontFamily"
    static let sizeUserPreferencesKey = "boopEditorFontSize"
    static let didChangeNotification = Notification.Name("BoopEditorFontDidChange")

    static let defaultSize: CGFloat = 15
    static let sizes: ClosedRange<CGFloat> = 9...36

    /// The saved family; nil is the system monospaced font (SF Mono).
    static var family: String? {
        guard let name = UserDefaults.standard.string(forKey: familyUserPreferencesKey), !name.isEmpty else { return nil }
        return name
    }

    static var size: CGFloat {
        let saved = UserDefaults.standard.double(forKey: sizeUserPreferencesKey)
        return saved > 0 ? clamp(CGFloat(saved)) : defaultSize
    }

    /// The saved font; falls back to the system monospaced font if the family was uninstalled.
    static var current: NSFont {
        let size = self.size
        if let family = family,
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Installed fixed-pitch families, sorted, without hidden system ones (".SF NS Mono").
    static var availableFamilies: [String] {
        let manager = NSFontManager.shared
        let names = manager.availableFontNames(with: .fixedPitchFontMask) ?? []
        let families = Set(names.compactMap { NSFont(name: $0, size: defaultSize)?.familyName })
        return families.filter { !$0.hasPrefix(".") }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func clamp(_ size: CGFloat) -> CGFloat {
        return min(max(size.rounded(), sizes.lowerBound), sizes.upperBound)
    }

    static func setFamily(_ family: String?) {
        UserDefaults.standard.set(family ?? "", forKey: familyUserPreferencesKey)
        didChange()
    }

    static func setSize(_ size: CGFloat) {
        let size = clamp(size)
        guard size != self.size else { return }
        UserDefaults.standard.set(Double(size), forKey: sizeUserPreferencesKey)
        didChange()
    }

    static func didChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
