//
//  BoopWindowController.swift
//  Boop
//
//  Created by Kirill on 11/15/26.
//

import Cocoa
import SavannaKit

/// One editor window. Each window is one native macOS tab.
class BoopWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {

    static let tabbingIdentifier = "BoopEditor"
    private static let frameAutosaveName = "boop.app.window"

    @IBOutlet weak var mainViewController: MainViewController!
    @IBOutlet weak var popoverViewController: PopoverViewController!

    let tabID: UUID

    init(tabID: UUID) {
        self.tabID = tabID
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("BoopWindowController is created in code")
    }

    override var windowNibName: NSNib.Name? {
        return "BoopWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else { return }
        window.delegate = self
        window.tabbingMode = .preferred
        window.tabbingIdentifier = BoopWindowController.tabbingIdentifier
        window.setFrameUsingName(BoopWindowController.frameAutosaveName)

        if let toolbar = window.toolbar,
           let statusItem = toolbar.items.first(where: { $0.view is StatusView }) {
            if #available(macOS 13.0, *) {
                toolbar.centeredItemIdentifiers = [statusItem.itemIdentifier]
            } else {
                toolbar.centeredItemIdentifier = statusItem.itemIdentifier
            }
        }

        mainViewController.onTextChange = { [weak self] text in
            guard let self = self else { return }
            WorkspaceController.shared.updateContent(text, forTab: self.tabID)
        }
    }

    var editor: SyntaxTextView {
        return mainViewController.editorView
    }

    var statusView: StatusView? {
        return popoverViewController.statusView
    }

    func show(title: String, content: String) {
        _ = window // loads the nib
        window?.title = title
        mainViewController.load(text: content)
    }

    func focusEditor() {
        window?.makeFirstResponder(editor.contentTextView)
    }

    // MARK: Tabs

    override func newWindowForTab(_ sender: Any?) {
        WorkspaceController.shared.newTab(nextTo: self)
    }

    @IBAction func renameTab(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let titleField = NSTextField(string: window?.title ?? "")
        titleField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = titleField
        alert.window.initialFirstResponder = titleField

        guard let window = window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self = self else { return }
            if let title = WorkspaceController.shared.renameTab(self.tabID, to: titleField.stringValue) {
                self.window?.title = title
            }
        }
    }

    @IBAction func selectNumberedTab(_ sender: NSMenuItem) {
        let tabs = window?.tabbedWindows ?? [window].compactMap { $0 }
        guard tabs.indices.contains(sender.tag) else { return }
        tabs[sender.tag].makeKeyAndOrderFront(nil)
    }

    // MARK: Picker and editor actions (menu items target First Responder)

    @IBAction func openPickerMenu(_ sender: Any) {
        popoverViewController.show()
    }

    @IBAction func closePickerMenu(_ sender: Any) {
        popoverViewController.hide()
    }

    @IBAction func executeLastScript(_ sender: Any) {
        popoverViewController.runScriptAgain()
    }

    @IBAction func clear(_ sender: Any) {
        mainViewController.clear()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openPickerMenu(_:)):
            menuItem.isHidden = popoverViewController.enabled
        case #selector(closePickerMenu(_:)):
            menuItem.isHidden = !popoverViewController.enabled
        case #selector(selectNumberedTab(_:)):
            let count = window?.tabbedWindows?.count ?? 1
            menuItem.isHidden = menuItem.tag >= count
            return menuItem.tag < count
        default:
            break
        }
        return true
    }

    // MARK: NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        WorkspaceController.shared.didSelect(self)
    }

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: BoopWindowController.frameAutosaveName)
        popoverViewController.tearDown()
        WorkspaceController.shared.didClose(self)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        window?.saveFrame(usingName: BoopWindowController.frameAutosaveName)
    }

    func windowDidMove(_ notification: Notification) {
        window?.saveFrame(usingName: BoopWindowController.frameAutosaveName)
    }
}
