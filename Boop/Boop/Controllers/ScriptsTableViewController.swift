//
//  ScriptsTableViewController.swift
//  Boop
//
//  Created by Ivan on 2/13/19.
//

import Cocoa

class ScriptsTableViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var tableView: ScriptTableView!
    
    var results: [Script] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    /// SF Symbols for the built-in icon names. Scripts keep using the same
    /// names; the bundled icons8 PDFs remain as a fallback.
    private static let symbolNames: [String: String] = [
        "abacus": "sum",
        "broom": "wand.and.stars",
        "camel": "textformat.abc",
        "collapse": "arrow.down.right.and.arrow.up.left",
        "color-wheel": "paintpalette",
        "colosseum": "building.columns",
        "command": "command",
        "counter": "number",
        "dice": "dice",
        "elephant": "chevron.left.forwardslash.chevron.right",
        "filtration": "line.3.horizontal.decrease",
        "fingerprint": "touchid",
        "flask": "testtube.2",
        "flip": "arrow.up.arrow.down",
        "globe": "globe",
        "html": "chevron.left.forwardslash.chevron.right",
        "identification": "person.text.rectangle",
        "kebab": "minus",
        "link": "link",
        "metamorphose": "arrow.triangle.2.circlepath",
        "percentage": "percent",
        "pineapple": "leaf",
        "quote": "text.quote",
        "roman": "lock.rotation",
        "scissors": "scissors",
        "snake": "textformat.abc.dottedunderline",
        "sort-characters": "textformat",
        "sort-numbers": "list.number",
        "table": "tablecells",
        "term": "terminal",
        "translation": "character.bubble",
        "type": "textformat.size",
        "unknown": "questionmark",
        "watch": "clock",
        "website": "network",
    ]

    private static let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)

    private func symbol(_ name: String) -> NSImage? {
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(Self.symbolConfiguration)
    }

    private func scriptIcon(identifier: String?) -> NSImage? {
        let identifier = identifier?.lowercased() ?? "unknown"

        if let name = Self.symbolNames[identifier], let image = symbol(name) {
            return image
        }
        if let namedImage = NSImage(named: "icons8-\(identifier)") {
            return namedImage
        }
        // Custom scripts may name any SF Symbol directly
        return symbol(identifier) ?? symbol("questionmark")
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {        
        
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "scriptCell"), owner: self) as! ScriptTableViewCell
        
        guard let script = scriptAt(row) else {
            fatalError("Missing script for index \(row).")
        }
        
        view.titleLabel.stringValue = script.name ?? "No Name 🤔"
        view.subtitleLabel.stringValue = script.desc ?? "No Description 😢"
        
        view.imageView?.image = self.scriptIcon(identifier: script.icon)
        
        return view
        
    }
    
    func scriptAt(_ index: Int) -> Script? {
        guard index < results.count else {
            return nil
        }
        return results[index]
    }
    
    var selectedScript:Script? {
        guard tableView.selectedRow >= 0 else {
            // Nothing selected, return first item
            return scriptAt(0)
        }
        return scriptAt(tableView.selectedRow)
    }
}
