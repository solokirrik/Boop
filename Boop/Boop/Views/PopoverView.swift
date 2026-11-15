//
//  PopoverView.swift
//  Boop
//
//  Created by Ivan on 1/27/19.
//

import Cocoa

class PopoverView: NSView {

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        self.wantsLayer = true
        self.layer?.cornerRadius = Backdrop.cornerRadius
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        self.layer?.borderWidth = 0.5

        Backdrop.pin(Backdrop.make(), below: self)
        self.setBorder()
    }

    func setBorder() {
        // A hairline edge so the panel separates from the text behind it
        self.layer?.borderColor = NSColor.separatorColor.cgColor(for: self.effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.setBorder()
    }
}
