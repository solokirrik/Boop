//
//  Catppuccin.swift
//  Boop
//
//  Created by Kirill on 11/16/26.
//

import Cocoa

/// Catppuccin, https://catppuccin.com/palette: Latte is the light flavor, Frappé,
/// Macchiato and Mocha are dark.
enum CatppuccinFlavor: Int, CaseIterable {
    case latte
    case frappe
    case macchiato
    case mocha

    var name: String {
        switch self {
        case .latte: return "Latte"
        case .frappe: return "Frappé"
        case .macchiato: return "Macchiato"
        case .mocha: return "Mocha"
        }
    }

    var palette: CatppuccinPalette {
        switch self {
        case .latte:
            return CatppuccinPalette(
                rosewater: 0xdc8a78, mauve: 0x8839ef, red: 0xd20f39, peach: 0xfe640b,
                yellow: 0xdf8e1d, green: 0x40a02b, teal: 0x179299, blue: 0x1e66f5,
                text: 0x4c4f69, overlay2: 0x7c7f93, base: 0xeff1f5)
        case .frappe:
            return CatppuccinPalette(
                rosewater: 0xf2d5cf, mauve: 0xca9ee6, red: 0xe78284, peach: 0xef9f76,
                yellow: 0xe5c890, green: 0xa6d189, teal: 0x81c8be, blue: 0x8caaee,
                text: 0xc6d0f5, overlay2: 0x949cbb, base: 0x303446)
        case .macchiato:
            return CatppuccinPalette(
                rosewater: 0xf4dbd6, mauve: 0xc6a0f6, red: 0xed8796, peach: 0xf5a97f,
                yellow: 0xeed49f, green: 0xa6da95, teal: 0x8bd5ca, blue: 0x8aadf4,
                text: 0xcad3f5, overlay2: 0x939ab7, base: 0x24273a)
        case .mocha:
            return CatppuccinPalette(
                rosewater: 0xf5e0dc, mauve: 0xcba6f7, red: 0xf38ba8, peach: 0xfab387,
                yellow: 0xf9e2af, green: 0xa6e3a1, teal: 0x94e2d5, blue: 0x89b4fa,
                text: 0xcdd6f4, overlay2: 0x9399b2, base: 0x1e1e2e)
        }
    }
}

/// The Catppuccin colors Boop's editor uses.
struct CatppuccinPalette {
    let rosewater, mauve, red, peach, yellow, green, teal, blue: NSColor
    let text, overlay2, base: NSColor

    init(rosewater: UInt32, mauve: UInt32, red: UInt32, peach: UInt32,
         yellow: UInt32, green: UInt32, teal: UInt32, blue: UInt32,
         text: UInt32, overlay2: UInt32, base: UInt32) {
        self.rosewater = NSColor(hex: rosewater)
        self.mauve = NSColor(hex: mauve)
        self.red = NSColor(hex: red)
        self.peach = NSColor(hex: peach)
        self.yellow = NSColor(hex: yellow)
        self.green = NSColor(hex: green)
        self.teal = NSColor(hex: teal)
        self.blue = NSColor(hex: blue)
        self.text = NSColor(hex: text)
        self.overlay2 = NSColor(hex: overlay2)
        self.base = NSColor(hex: base)
    }

    /// Follows Catppuccin's style guide where Boop's token types allow it.
    var syntax: SyntaxColors {
        return SyntaxColors(
            text: text,
            background: base,
            cursor: rosewater,
            selection: overlay2.withAlphaComponent(0.3),
            comment: overlay2,
            string: green,
            attribute: mauve,  // var, let, if, return…, and tags
            keyword: yellow,   // true, false, type names
            number: peach,
            extra: blue)       // JSON keys
    }
}

extension NSColor {
    /// An sRGB color from 0xRRGGBB.
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: 1)
    }
}
