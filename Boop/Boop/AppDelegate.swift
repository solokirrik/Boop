//
//  AppDelegate.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    private var workspace: WorkspaceController {
        return WorkspaceController.shared
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        ThemeSettingsViewController.applyTheme()
        WindowTransparency.observeAccessibility()
        NSApp.servicesProvider = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installTabMenus()
        installFontSizeMenu()
        installMultiCursorMenu()
        workspace.restoreWindows()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Windows closing during quit keep their tabs
        workspace.isTerminating = true
        workspace.flush()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: Menus

    private func installTabMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }

        if let fileMenu = mainMenu.item(withTitle: "File")?.submenu {
            if let closeItem = fileMenu.items.first(where: { $0.keyEquivalent.lowercased() == "w" }) {
                closeItem.title = "Close Tab"
            }

            // Sent along the responder chain to the key window's controller
            let newTabItem = NSMenuItem(title: "New Tab", action: #selector(NSResponder.newWindowForTab(_:)), keyEquivalent: "t")
            let renameItem = NSMenuItem(title: "Rename Tab…", action: #selector(BoopWindowController.renameTab(_:)), keyEquivalent: "")

            fileMenu.insertItem(NSMenuItem.separator(), at: 0)
            fileMenu.insertItem(renameItem, at: 0)
            fileMenu.insertItem(newTabItem, at: 0)
        }

        if let windowMenu = mainMenu.item(withTitle: "Window")?.submenu {
            windowMenu.addItem(NSMenuItem.separator())
            for index in 0..<9 {
                let item = NSMenuItem(title: "Tab \(index + 1)", action: #selector(BoopWindowController.selectNumberedTab(_:)), keyEquivalent: "\(index + 1)")
                item.keyEquivalentModifierMask = [.command]
                item.tag = index
                windowMenu.addItem(item)
            }
        }
    }

    /// View > Bigger / Smaller / Actual Size change the editor font size in every window.
    private func installFontSizeMenu() {
        guard let viewMenu = NSApp.mainMenu?.item(withTitle: "View")?.submenu else { return }

        let bigger = NSMenuItem(title: "Bigger", action: #selector(makeTextBigger(_:)), keyEquivalent: "+")
        // ⌘= is the unshifted key for ⌘+ on most layouts
        let biggerAlternate = NSMenuItem(title: "Bigger", action: #selector(makeTextBigger(_:)), keyEquivalent: "=")
        biggerAlternate.isHidden = true
        biggerAlternate.allowsKeyEquivalentWhenHidden = true
        let smaller = NSMenuItem(title: "Smaller", action: #selector(makeTextSmaller(_:)), keyEquivalent: "-")
        let actualSize = NSMenuItem(title: "Actual Size", action: #selector(makeTextActualSize(_:)), keyEquivalent: "0")

        let items = [bigger, biggerAlternate, smaller, actualSize, .separator()]
        for (index, item) in items.enumerated() {
            item.target = self
            viewMenu.insertItem(item, at: index)
        }
    }

    /// Edit > Multiple Cursors. The items go along the responder chain to the editor.
    private func installMultiCursorMenu() {
        guard let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu,
              let selectAllIndex = editMenu.items.firstIndex(where: { $0.action == #selector(NSText.selectAll(_:)) }) else { return }

        func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            return item
        }
        let up = String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        let down = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))

        let submenu = NSMenu(title: "Multiple Cursors")
        submenu.items = [
            item("Add Cursor Above", #selector(EditorTextView.addCursorAbove(_:)), up, [.command, .option]),
            item("Add Cursor Below", #selector(EditorTextView.addCursorBelow(_:)), down, [.command, .option]),
            .separator(),
            item("Select Next Occurrence", #selector(EditorTextView.selectNextOccurrence(_:)), "d", [.command]),
            item("Select All Occurrences", #selector(EditorTextView.selectAllOccurrences(_:)), "g", [.command, .control]),
            item("Split Selection into Lines", #selector(EditorTextView.splitSelectionIntoLines(_:)), "l", [.command, .shift])
        ]
        let parent = NSMenuItem(title: "Multiple Cursors", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        editMenu.insertItem(parent, at: selectAllIndex + 1)
    }

    @IBAction func makeTextBigger(_ sender: Any) {
        EditorFont.setSize(EditorFont.size + 1)
    }

    @IBAction func makeTextSmaller(_ sender: Any) {
        EditorFont.setSize(EditorFont.size - 1)
    }

    @IBAction func makeTextActualSize(_ sender: Any) {
        EditorFont.setSize(EditorFont.defaultSize)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(makeTextBigger(_:)): return EditorFont.size < EditorFont.sizes.upperBound
        case #selector(makeTextSmaller(_:)): return EditorFont.size > EditorFont.sizes.lowerBound
        case #selector(makeTextActualSize(_:)): return EditorFont.size != EditorFont.defaultSize
        default: return true
        }
    }

    @IBAction func showPreferencesWindow(_ sender: NSMenuItem) {
        let controller = NSStoryboard.init(name: "Preferences", bundle: nil).instantiateInitialController() as? NSWindowController

        controller?.showWindow(sender)
    }

    @IBAction func reloadScripts(_ sender: Any) {
        ScriptManager.shared.reloadScripts(status: workspace.keyController?.statusView)
    }

    @IBAction func openHelp(_ sender: Any) {
        open(url: "https://github.com/solokirrik/Boop/blob/main/Boop/Documentation/Readme.md")
    }

    @IBAction func openScripts(_ sender: Any) {
        open(url: "https://github.com/solokirrik/Boop/tree/main/Scripts")
    }

    private func open(url: String) {
        guard let url = URL(string: url) else {
            assertionFailure("Could not generate help URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: Services

    @objc func textServiceHandler(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let string = pboard.string(forType: NSPasteboard.PasteboardType.string),
              let editor = workspace.keyController?.editor else { return }
        editor.contentTextView.string = string
        editor.contentTextView.didChangeText()
    }
}
