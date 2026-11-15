//
//  AppDelegate.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa
import SavannaKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var workspace: WorkspaceController {
        return WorkspaceController.shared
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        ThemeSettingsViewController.applyTheme()
        NSApp.servicesProvider = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installTabMenus()
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

    @IBAction func showPreferencesWindow(_ sender: NSMenuItem) {
        let controller = NSStoryboard.init(name: "Preferences", bundle: nil).instantiateInitialController() as? NSWindowController

        controller?.showWindow(sender)
    }

    @IBAction func reloadScripts(_ sender: Any) {
        ScriptManager.shared.reloadScripts(status: workspace.keyController?.statusView)
    }

    @IBAction func openHelp(_ sender: Any) {
        open(url: "https://boop.okat.best/docs/")
    }

    @IBAction func openScripts(_ sender: Any) {
        open(url: "https://boop.okat.best/scripts/")
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
