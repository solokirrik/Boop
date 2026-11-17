//
//  DefaultTheme.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa

/// The editor's color theme, picked in Settings > Appearance.
enum EditorThemeChoice: Int, CaseIterable {
    case boop
    case catppuccinLatte
    case catppuccinFrappe
    case catppuccinMacchiato
    case catppuccinMocha

    static let userPreferencesKey = "boopEditorTheme"
    static let didChangeNotification = Notification.Name("BoopEditorThemeDidChange")

    static var current: EditorThemeChoice {
        return EditorThemeChoice(rawValue: UserDefaults.standard.integer(forKey: userPreferencesKey)) ?? .boop
    }

    var catppuccinFlavor: CatppuccinFlavor? {
        switch self {
        case .boop: return nil
        case .catppuccinLatte: return .latte
        case .catppuccinFrappe: return .frappe
        case .catppuccinMacchiato: return .macchiato
        case .catppuccinMocha: return .mocha
        }
    }

    var name: String {
        guard let flavor = catppuccinFlavor else { return "Boop" }
        return "Catppuccin \(flavor.name)"
    }

    /// A light or dark only theme sets the app appearance; nil follows the Color Scheme setting.
    var appearance: NSAppearance.Name? {
        guard let flavor = catppuccinFlavor else { return nil }
        return flavor == .latte ? .aqua : .darkAqua
    }

    static func didChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}

/// Every color the editor paints with.
struct SyntaxColors {
    let text: NSColor
    let background: NSColor
    let cursor: NSColor
    /// nil keeps the system selection color
    let selection: NSColor?
    let comment, string, attribute, keyword, number, extra: NSColor

    /// Boop's own colors, on the system text colors.
    static func boop(for appearance: NSAppearance) -> SyntaxColors {
        let text = NSColor.textColor.resolved(for: appearance)
        return SyntaxColors(
            text: text,
            background: NSColor.textBackgroundColor.resolved(for: appearance),
            cursor: text,
            selection: nil,
            comment: ColorPair.comments.value(for: appearance),
            string: ColorPair.red.value(for: appearance),
            attribute: ColorPair.cyanish.value(for: appearance),
            keyword: ColorPair.green.value(for: appearance),
            number: ColorPair.orangish.value(for: appearance),
            extra: ColorPair.blue.value(for: appearance))
    }
}

/// Editor font and colors for one appearance (light or dark).
struct EditorTheme {

    let appearance: NSAppearance
    let colors: SyntaxColors

    init(appearance: NSAppearance, choice: EditorThemeChoice = .current) {
        self.appearance = appearance
        colors = choice.catppuccinFlavor?.palette.syntax ?? .boop(for: appearance)
    }

    let tabWidth = 4
    let font = EditorFont.current

    var textColor: NSColor {
        return colors.text
    }

    var backgroundColor: NSColor {
        return colors.background
    }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 2
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        style.defaultTabInterval = spaceWidth * CGFloat(tabWidth)
        style.tabStops = []
        return style
    }

    /// Attributes for text with no syntax color.
    var baseAttributes: [NSAttributedString.Key: Any] {
        return [.font: font, .foregroundColor: textColor, .paragraphStyle: paragraphStyle]
    }

    func color(for type: BoopToken.TokenType) -> NSColor {
        switch type {
        case .comment: return colors.comment
        case .string: return colors.string
        case .attribute: return colors.attribute
        case .number: return colors.number
        case .extra: return colors.extra
        case .keyword: return colors.keyword
        }
    }
}
