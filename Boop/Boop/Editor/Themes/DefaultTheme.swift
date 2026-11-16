//
//  DefaultTheme.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa

/// Editor font and colors for one appearance (light or dark).
struct EditorTheme {

    let appearance: NSAppearance

    let tabWidth = 4
    let font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)

    var textColor: NSColor {
        return NSColor.textColor.resolved(for: appearance)
    }

    var backgroundColor: NSColor {
        return NSColor.textBackgroundColor.resolved(for: appearance)
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
        case .comment:
            return ColorPair.comments.value(for: appearance)
        case .string:
            return ColorPair.red.value(for: appearance)
        case .attribute:
            return ColorPair.cyanish.value(for: appearance)
        case .number:
            return ColorPair.orangish.value(for: appearance)
        case .extra:
            return ColorPair.blue.value(for: appearance)
        case .keyword:
            return ColorPair.green.value(for: appearance)
        }
    }
}
