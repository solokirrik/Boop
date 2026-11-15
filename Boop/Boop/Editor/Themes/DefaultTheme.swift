//
//  DefaultTheme.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa
import SavannaKit

class DefaultTheme: SyntaxColorTheme {

    let appearance: NSAppearance
    
    var tabWidth: Int = 4
    
    var gutterStyle: GutterStyle {
        GutterStyle(
            backgroundColor: NSColor.textBackgroundColor.resolved(for: appearance),
            separatorColor: NSColor.separatorColor.resolved(for: appearance),
            minimumWidth: 40
        )
    }
    
    var font: Font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    
    let lineNumbersStyle: LineNumbersStyle?
    
    var backgroundColor: Color {
        return NSColor.textBackgroundColor.resolved(for: appearance)
    }
    
    
    init(appearance: NSAppearance) {
        self.appearance = appearance
        lineNumbersStyle = LineNumbersStyle(font: font, textColor: NSColor.tertiaryLabelColor.resolved(for: appearance))
    }
    
    func globalAttributes() -> [NSAttributedString.Key: Any] {
        
        var attributes = [NSAttributedString.Key: Any]()
        
        attributes[.font] = self.font
        attributes[.foregroundColor] = NSColor.textColor.resolved(for: appearance)
        
        return attributes
    }
    
    func attributes(for token: Token) -> [NSAttributedString.Key : Any] {
        
        guard let token = token as? BoopToken else {
            return [:]
        }
        
        switch token.type {
        case .comment:
            return [.foregroundColor: ColorPair.comments.value(for: appearance)]
        case .string:
            return [.foregroundColor: ColorPair.red.value(for: appearance)]
        case .attribute:
            return [.foregroundColor: ColorPair.cyanish.value(for: appearance)]
        case .number:
            return [.foregroundColor: ColorPair.orangish.value(for: appearance)]
        case .extra:
            return [.foregroundColor: ColorPair.blue.value(for: appearance)]
        case .keyword:
            return [.foregroundColor: ColorPair.green.value(for: appearance)]
        }
    }
    
}
