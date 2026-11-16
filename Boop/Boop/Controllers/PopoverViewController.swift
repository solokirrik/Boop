//
//  PopoverViewController.swift
//  Boop
//
//  Created by Ivan on 1/27/19.
//

import Cocoa

fileprivate let kVKTab = 0x30
fileprivate let kVKB = 0x0B
fileprivate let kVKP = 0x23
    // 125 is down arrow
    // 126 is up
    // 53 is escape
    // 36 is enter

fileprivate enum MoveCommand {
    case up, down
}

fileprivate let moveDownControlKeys = ["j", "n"]
fileprivate let moveUpControlKeys = ["k", "p"]

fileprivate func extractMoveCommand(fromEvent event: NSEvent) -> MoveCommand? {
    if event.keyCode == kVKTab {
        return event.modifierFlags.contains(.shift) ? .up : .down
    }
    if event.modifierFlags.contains(.control),
       let chars = event.charactersIgnoringModifiers {
        if moveDownControlKeys.contains(chars) {
            return .down
        }
        else if moveUpControlKeys.contains(chars) {
            return .up
        }
    }
    return nil
}


class PopoverViewController: NSViewController {
    
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var popoverView: PopoverContainerView!
    @IBOutlet weak var searchField: SearchField!
    @IBOutlet weak var editorView: EditorView!
    @IBOutlet weak var statusView: StatusView!

    @IBOutlet weak var tableView: ScriptTableView!
    @IBOutlet weak var tableHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewController: ScriptsTableViewController!

    let scriptManager = ScriptManager.shared

    var enabled = false // Closed by default

    /// The app-wide key monitor; removed when this window's tab closes.
    private var keyMonitor: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Double-click script selection
        tableView.doubleAction = #selector(runSelectedScript)

        // Show popover on status view click
        statusView.onMouseDown = { [weak self] in
            self?.show()
        }

        // Dismiss popover on background view click
        overlayView.onMouseDown = { [weak self] in
            self?.hide()
        }
        
        setupKeyHandlers()
    }
    
    func setupKeyHandlers() {
        
        var keyHandler: (_: NSEvent) -> NSEvent?
        keyHandler = { [weak self]
            (_ theEvent: NSEvent) -> NSEvent? in

            // Every tab has its own picker; only handle keys for this window.
            guard let self = self, theEvent.window === self.view.window else {
                return theEvent
            }
            
            var didSomething = false

            // ⌘P is the menu shortcut; ⌘B (classic Boop) and ⇧⌘P (command palette) open the picker too
            if !self.enabled {
                let modifiers = theEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let isCommandB = theEvent.keyCode == kVKB && modifiers == [.command]
                let isShiftCommandP = theEvent.keyCode == kVKP && modifiers == [.command, .shift]
                if isCommandB || isShiftCommandP {
                    self.show()
                    return nil
                }
            }
                
            if theEvent.keyCode == 53 && self.enabled { // ESCAPE
                
                // Let's dismiss the popover
                self.hide()
                
                didSomething = true
            }
            
            if theEvent.keyCode == 36 && self.enabled { // ENTER

                guard self.tableViewController.selectedScript != nil else {
                    return theEvent
                }

                self.runSelectedScript()
                
                didSomething = true
            }

            let window = self.view.window
            
            if self.enabled,
               let moveCommand = extractMoveCommand(fromEvent: theEvent) {
                if window?.firstResponder is NSTextView &&
                    (window?.firstResponder as! NSTextView).delegate is SearchField {
                    let offset = moveCommand == .up ? -1 : 1
                    let newSel = IndexSet([self.tableView.selectedRow + offset])
                    self.tableView.selectRowIndexes(newSel, byExtendingSelection: false)
                    self.tableView.scrollRowToVisible(self.tableView.selectedRow)
                }
                didSomething = true // prevent tabbing back into text document
            }

            if window?.firstResponder is NSTextView &&
                (window?.firstResponder as! NSTextView).delegate is SearchField &&
                theEvent.keyCode == 125 { // DOWN
                
                // Why -1? I don't know, and I don't even care.
                let indexSet = IndexSet(integer: -1)
                self.tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                window?.makeFirstResponder(self.tableView)
            }
            
            // Oh hey look now somehow it's 0.
            if window?.firstResponder is NSTableView &&
                self.tableView.selectedRow == 0 &&
                theEvent.keyCode == 126 { // UP
                
                window?.makeFirstResponder(self.searchField)
                // This doesn't work for some reason.
                //self.searchField.moveToEndOfLine(nil)
            }
            
            guard didSomething else {
                return theEvent
            }
            
            // Return an empty event to avoid the funk sound
            return nil
        }
        
        // Creates an object we do not own, but must keep track
        // of it so that it can be "removed" when we're done
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyHandler)
        
    }
    
    func show() {
        overlayView.show()
        popoverView.show()
        
        // FIXME: Use localized strings
        statusView.setStatus(.help("Select your action"))
        
        self.searchField.stringValue = ""
        
        let allScriptsList = scriptManager.scripts.sorted { left, right in
            left.name ?? "" < right.name ?? ""
        }
        self.tableViewController.results = allScriptsList
        self.tableHeightConstraint.constant = tableHeight(rows: allScriptsList.count)
        
        self.view.window?.makeFirstResponder(self.searchField)
        self.enabled = true
    }
    
    func hide() {
        overlayView.hide()
        popoverView.hide()
        
        statusView.setStatus(.normal)
        
        self.view.window?.makeFirstResponder(self.editorView.contentTextView)
        self.enabled = false
        self.tableHeightConstraint.animator().constant = 0
        
        tableViewController.results = []
    }

    func runScriptAgain() {
        scriptManager.runScriptAgain(textView: editorView.contentTextView, status: statusView)
    }

    /// Called when this window's tab closes.
    func tearDown() {
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    @objc private func runSelectedScript() {
        guard let script = tableViewController.selectedScript else {
            return
        }

        // Let's dismiss the popover
        hide()

        // Run the script afterwards in case we need to show a status
        scriptManager.runScript(script, into: editorView.contentTextView, status: statusView)
    }

    /// Height of the results list: up to 5 visible rows (45pt + 2pt spacing)
    /// plus a small bottom margin, without revealing part of a 6th row.
    func tableHeight(rows: Int) -> CGFloat {
        guard rows > 0 else { return 0 }
        return CGFloat(47 * min(5, rows) + 4)
    }
}

extension PopoverViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard (obj.object as? SearchField) == searchField else {
            return
        }
        
        let results = scriptManager.search(searchField.stringValue)
        tableViewController.results = results
        
        self.tableHeightConstraint.constant = tableHeight(rows: results.count)
    }
}
