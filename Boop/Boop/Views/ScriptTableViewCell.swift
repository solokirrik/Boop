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
    
}
