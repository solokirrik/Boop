//
//  ScriptTableViewCell.swift
//  Boop
//
//  Created by Ivan on 2/13/19.
//

import Cocoa

class ScriptTableViewCell: NSTableCellView {
    weak var script:Script!
   
    @IBOutlet weak var titleLabel:NSTextField!
    @IBOutlet weak var subtitleLabel:NSTextField!

    /// The theme's accent; nil keeps the system label color.
    var iconTint: NSColor? {
        didSet { updateIconTint() }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { updateIconTint() }
    }

    /// A custom tint stops the icon turning white on the selected row, so do that here.
    private func updateIconTint() {
        imageView?.contentTintColor = backgroundStyle == .emphasized ? nil : iconTint
    }
}
