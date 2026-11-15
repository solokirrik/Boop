//
//  Colors.swift
//  Boop
//
//  Created by Ivan on 9/29/19.
//

import Cocoa

struct Colors {
    
    static let redey: NSColor = #colorLiteral(red: 1, green: 0.2980392157, blue: 0.4862745098, alpha: 1) // #ff4c7c
    static let bluish: NSColor = #colorLiteral(red: 0.5, green: 0.8870540044, blue: 1, alpha: 1) // #3586FF
    static let cyanish: NSColor = #colorLiteral(red: 0.1595847315, green: 0.951053901, blue: 0.7986315017, alpha: 1) // #4cffb2
    static let greenish: NSColor = #colorLiteral(red: 0.6049238592, green: 1, blue: 0, alpha: 1) // #32FF47
    static let orangeish: NSColor = #colorLiteral(red: 1, green: 0.6980392157, blue: 0.2980392157, alpha: 1) // #ffb24c
    static let yellowishy: NSColor = #colorLiteral(red: 0.9882352941, green: 1, blue: 0.2980392157, alpha: 1) // #fcff4c
    static let commentGrey: NSColor = #colorLiteral(red: 0.7008966023, green: 0.7301803691, blue: 0.8538076556, alpha: 1) // #9BCCE3
    static let redButDarker: NSColor = #colorLiteral(red: 0.7254901961, green: 0.09411764706, blue: 0.262745098, alpha: 1) // #B91843
    static let blueButDarker: NSColor = #colorLiteral(red: 0, green: 0.4156862745, blue: 0.7176470588, alpha: 1) // #006AB7
    static let greenButDarker: NSColor = #colorLiteral(red: 0, green: 0.6980392157, blue: 0, alpha: 1) // #00B200
    static let purpleButDarker: NSColor = #colorLiteral(red: 0.462745098, green: 0, blue: 0.462745098, alpha: 1) // #760076
    static let orangeABitDarker: NSColor = #colorLiteral(red: 1, green: 0.3960784314, blue: 0.1764705882, alpha: 1) // #FF652D
    static let cyanTinyBitDarker: NSColor = #colorLiteral(red: 0, green: 0.6941176471, blue: 0.7176470588, alpha: 1) // #00B1B7
    static let commentGreyDarkest: NSColor = #colorLiteral(red: 0.5333333333, green: 0.5568627451, blue: 0.6509803922, alpha: 1) // #888EA6
    static let purpleButItsLighter: NSColor = #colorLiteral(red: 0.9725490196, green: 0.6470588235, blue: 0.9725490196, alpha: 1) // #F8A5F8
    
    static func dynamicColor(light: NSColor, dark: NSColor, for appearance: NSAppearance) -> NSColor {
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
           return dark
        } else {
           return light
        }
    }
}

extension NSColor {
    /// Resolves a dynamic (system) color for a given appearance, for use on CALayers.
    func cgColor(for appearance: NSAppearance) -> CGColor {
        var resolved = self.cgColor
        appearance.performAsCurrentDrawingAppearance {
            resolved = self.cgColor
        }
        return resolved
    }
}

enum Backdrop {
    static let cornerRadius: CGFloat = 16

    /// A translucent background: Liquid Glass on macOS 26+, a popover material before that.
    static func make(cornerRadius: CGFloat = Backdrop.cornerRadius) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            return glass
        }

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        return effect
    }

    static func pin(_ view: NSView, below siblings: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        siblings.addSubview(view, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: siblings.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: siblings.trailingAnchor),
            view.topAnchor.constraint(equalTo: siblings.topAnchor),
            view.bottomAnchor.constraint(equalTo: siblings.bottomAnchor)
        ])
    }
}

struct ColorPair {
    
    static let red = ColorPair(light: Colors.redButDarker, dark: Colors.redey)
    static let blue = ColorPair(light: Colors.blueButDarker, dark: Colors.bluish)
    static let green = ColorPair(light: Colors.greenButDarker, dark: Colors.greenish)
    static let cyanish = ColorPair(light: Colors.cyanTinyBitDarker, dark: Colors.cyanish)
    static let orangish = ColorPair(light: Colors.orangeABitDarker, dark: Colors.orangeish)
    
    static let body = ColorPair(light: .init(white: 0.1, alpha: 1), dark: .white)
    static let gutter = ColorPair(light: .init(white: 240/255, alpha: 1), dark: .init(white: 27/255, alpha: 1))
    
    static let comments = ColorPair(light: Colors.commentGreyDarkest, dark: Colors.commentGreyDarkest)
    static let separator = ColorPair(light: .init(white: 220/255, alpha: 1), dark: .init(white: 45/255, alpha: 1))
    static let background = ColorPair(light: .init(white: 0.95, alpha: 1.0), dark: .init(white: 31/255, alpha: 1.0))
    static let overlayColor = ColorPair(light: .init(white: 0, alpha: 0.12), dark: .init(white: 0, alpha: 0.35))
    
    
    let light: NSColor
    let dark: NSColor
    
    func value(for appearance: NSAppearance) -> NSColor {
        return Colors.dynamicColor(light: self.light, dark: self.dark, for: appearance)
    }

    var swap: ColorPair {
        return ColorPair(light: self.dark, dark: self.light)
    }
}


