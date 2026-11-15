//
//  SearchField.swift
//  Boop
//
//  Created by Ivan on 1/27/19.
//

import Cocoa

class SearchField: NSTextField {

    override func awakeFromNib() {
        super.awakeFromNib()
        self.drawsBackground = false
        self.isBordered = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
