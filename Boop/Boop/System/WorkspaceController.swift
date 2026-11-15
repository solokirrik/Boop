//
//  WorkspaceController.swift
//  Boop
//
//  Created by Kirill on 11/15/26.
//

import Cocoa

/// Keeps the saved tabs (`ScratchpadWorkspace`) in sync with the open windows:
/// every tab is one native window tab.
final class WorkspaceController {

    static let shared = WorkspaceController()

    private let store: ScratchpadWorkspaceStore
    private(set) var workspace: ScratchpadWorkspace
    private(set) var controllers = [BoopWindowController]()
    private var pendingSave: DispatchWorkItem?
    private var lifecycleObservers = [NSObjectProtocol]()

    /// Set while the app quits, so closing windows keeps their tabs.
    var isTerminating = false

    init(store: ScratchpadWorkspaceStore = ScratchpadWorkspaceStore()) {
        self.store = store
        self.workspace = store.load()
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: Windows

    /// Opens one window per saved tab, grouped as tabs, and selects the saved tab.
    func restoreWindows() {
        observeLifecycle()

        let selectedID = workspace.selectedTabID
        var previous: NSWindow?

        for tab in workspace.tabs {
            let controller = makeController(for: tab)
            guard let window = controller.window else { continue }

            if let previous = previous {
                previous.addTabbedWindow(window, ordered: .above)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            previous = window
        }

        let selected = controller(for: selectedID) ?? controllers.first
        selected?.window?.makeKeyAndOrderFront(nil)
        selected?.focusEditor()
    }

    func newTab(nextTo current: BoopWindowController?) {
        let tab = workspace.createTab()
        let controller = makeController(for: tab)

        if let currentWindow = current?.window, let window = controller.window {
            currentWindow.addTabbedWindow(window, ordered: .above)
        }
        controller.window?.makeKeyAndOrderFront(nil)
        controller.focusEditor()
        scheduleSave()
    }

    var keyController: BoopWindowController? {
        return NSApp.keyWindow?.windowController as? BoopWindowController
            ?? NSApp.mainWindow?.windowController as? BoopWindowController
            ?? controller(for: workspace.selectedTabID)
            ?? controllers.first
    }

    private func makeController(for tab: Scratchpad) -> BoopWindowController {
        let controller = BoopWindowController(tabID: tab.id)
        controller.show(title: tab.title, content: tab.content)
        controllers.append(controller)
        return controller
    }

    private func controller(for id: UUID) -> BoopWindowController? {
        return controllers.first(where: { $0.tabID == id })
    }

    // MARK: Events from windows

    func updateContent(_ content: String, forTab id: UUID) {
        workspace.updateContent(content, forTab: id)
        scheduleSave()
    }

    /// Returns the applied title, or nil if it was empty.
    func renameTab(_ id: UUID, to title: String) -> String? {
        workspace.renameTab(id: id, to: title)
        scheduleSave()
        let applied = workspace.tab(withID: id)?.title
        return applied == title.trimmingCharacters(in: .whitespacesAndNewlines) ? applied : nil
    }

    func didSelect(_ controller: BoopWindowController) {
        workspace.select(tabID: controller.tabID)
        scheduleSave()
    }

    func didClose(_ controller: BoopWindowController) {
        controllers.removeAll(where: { $0 === controller })
        guard !isTerminating else { return }

        workspace.removeTab(id: controller.tabID)
        if controllers.isEmpty {
            // Last tab closed: the app quits, save now
            flush()
        } else {
            scheduleSave()
        }
    }

    // MARK: Saving

    /// Tab order as shown on screen: tab groups front to back, tabs left to right.
    private func syncOrderFromWindows() {
        var seen = Set<ObjectIdentifier>()
        var ids = [UUID]()

        for window in NSApp.orderedWindows {
            for tabWindow in window.tabbedWindows ?? [window] {
                guard seen.insert(ObjectIdentifier(tabWindow)).inserted,
                      let controller = tabWindow.windowController as? BoopWindowController,
                      controllers.contains(where: { $0 === controller }) else { continue }
                ids.append(controller.tabID)
            }
        }
        // Minimized windows are not in orderedWindows; keep them in place at the end
        workspace.reorder(by: ids)
    }

    func scheduleSave() {
        pendingSave?.cancel()
        let save = DispatchWorkItem { [weak self] in
            self?.flush()
        }
        pendingSave = save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: save)
    }

    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        if !controllers.isEmpty {
            syncOrderFromWindows()
        }

        do {
            try store.save(workspace)
        } catch {
            NSLog("Unable to save Boop tabs: %@", error.localizedDescription)
        }
    }

    private func observeLifecycle() {
        guard lifecycleObservers.isEmpty else { return }
        let notifications: [Notification.Name] = [
            NSApplication.willTerminateNotification,
            NSApplication.didResignActiveNotification
        ]

        lifecycleObservers = notifications.map { name in
            NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] _ in
                self?.flush()
            }
        }
    }
}
