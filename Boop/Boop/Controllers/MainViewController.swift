//
//  MainViewController.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa
import SavannaKit

class MainViewController: NSViewController {

    @IBOutlet weak var editorView: SyntaxTextView!

    private let workspaceStore = ScratchpadWorkspaceStore()
    private var workspace = ScratchpadWorkspace()
    private var pendingSave: DispatchWorkItem?
    private var lifecycleObservers = [NSObjectProtocol]()
    private var isLoadingTab = false

    private let tabBar = NSVisualEffectView()
    private let tabScrollView = NSScrollView()
    private let tabStackView = NSStackView()
    private let addTabButton = NSButton()
    private let closeTabButton = NSButton()
    private var numberedTabMenuItems = [NSMenuItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        isLoadingTab = true

        installCompatibleLayoutManager()
        
        
        editorView.delegate = self

        editorView.contentTextView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]

        workspace = workspaceStore.load()
        installTabBar()
        DispatchQueue.main.async { [weak self] in
            self?.installScratchpadMenus()
        }
        observeLifecycle()
        loadSelectedTab()
        refreshTabs()
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func installCompatibleLayoutManager() {
        guard let textStorage = editorView.contentTextView.textStorage,
              let textContainer = editorView.contentTextView.textContainer,
              let currentLayoutManager = editorView.contentTextView.layoutManager,
              let containerIndex = currentLayoutManager.textContainers.firstIndex(where: { $0 === textContainer }) else {
            return
        }

        let layoutManager = NSLayoutManager()
        currentLayoutManager.removeTextContainer(at: containerIndex)
        textStorage.removeLayoutManager(currentLayoutManager)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
    }

    @IBAction func newTab(_ sender: Any) {
        captureEditorContent()
        workspace.createTab()
        loadSelectedTab()
        workspaceDidChange()
    }

    @IBAction func closeTab(_ sender: Any) {
        captureEditorContent()
        workspace.closeSelectedTab()
        loadSelectedTab()
        workspaceDidChange()
    }

    @IBAction func renameTab(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let titleField = NSTextField(string: workspace.selectedTab.title)
        titleField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = titleField
        alert.window.initialFirstResponder = titleField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        workspace.renameSelectedTab(to: titleField.stringValue)
        workspaceDidChange()
    }

    @IBAction func moveTabLeft(_ sender: Any) {
        captureEditorContent()
        workspace.moveSelectedTab(by: -1)
        workspaceDidChange()
    }

    @IBAction func moveTabRight(_ sender: Any) {
        captureEditorContent()
        workspace.moveSelectedTab(by: 1)
        workspaceDidChange()
    }

    @objc private func selectTab(_ sender: NSButton) {
        switchToTab(at: sender.tag)
    }

    @objc private func selectNumberedTab(_ sender: NSMenuItem) {
        switchToTab(at: sender.tag)
    }

    private func switchToTab(at index: Int) {
        guard workspace.tabs.indices.contains(index), index != workspace.selectedIndex else { return }
        captureEditorContent()
        workspace.selectTab(at: index)
        loadSelectedTab()
        workspaceDidChange()
    }

    func flushWorkspace() {
        captureEditorContent()
        pendingSave?.cancel()
        pendingSave = nil

        do {
            try workspaceStore.save(workspace)
        } catch {
            NSLog("Unable to save Boops tabs: %@", error.localizedDescription)
        }
    }

    private func captureEditorContent() {
        guard !isLoadingTab else { return }
        workspace.updateSelectedContent(editorView.contentTextView.string)
    }

    private func loadSelectedTab() {
        isLoadingTab = true
        let textView = editorView.contentTextView
        textView.string = workspace.selectedTab.content
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.removeAllActions()
        isLoadingTab = false
        view.window?.makeFirstResponder(textView)
    }

    private func workspaceDidChange() {
        refreshTabs()
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let save = DispatchWorkItem { [weak self] in
            self?.flushWorkspace()
        }
        pendingSave = save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: save)
    }

    private func observeLifecycle() {
        let notifications: [Notification.Name] = [
            NSApplication.willTerminateNotification,
            NSApplication.didResignActiveNotification
        ]

        lifecycleObservers = notifications.map { name in
            NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] _ in
                self?.flushWorkspace()
            }
        }
    }

    private func installTabBar() {
        guard let container = editorView.superview else { return }

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.material = .titlebar
        tabBar.blendingMode = .withinWindow
        tabBar.state = .active
        container.addSubview(tabBar, positioned: .above, relativeTo: nil)

        tabScrollView.translatesAutoresizingMaskIntoConstraints = false
        tabScrollView.drawsBackground = false
        tabScrollView.borderType = .noBorder
        tabScrollView.hasVerticalScroller = false
        tabScrollView.hasHorizontalScroller = true
        tabScrollView.autohidesScrollers = true
        tabStackView.orientation = .horizontal
        tabStackView.alignment = .centerY
        tabStackView.spacing = 4
        tabScrollView.documentView = tabStackView
        tabBar.addSubview(tabScrollView)

        configureBarButton(addTabButton, symbolName: "plus", toolTip: "New Tab (⌘T)", action: #selector(newTab(_:)))
        configureBarButton(closeTabButton, symbolName: "xmark", toolTip: "Close Tab (⌘W)", action: #selector(closeTab(_:)))
        tabBar.addSubview(addTabButton)
        tabBar.addSubview(closeTabButton)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: container.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 34),
            tabScrollView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 8),
            tabScrollView.topAnchor.constraint(equalTo: tabBar.topAnchor, constant: 3),
            tabScrollView.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: -3),
            tabScrollView.trailingAnchor.constraint(equalTo: addTabButton.leadingAnchor, constant: -6),
            addTabButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            addTabButton.widthAnchor.constraint(equalToConstant: 26),
            addTabButton.heightAnchor.constraint(equalToConstant: 24),
            closeTabButton.leadingAnchor.constraint(equalTo: addTabButton.trailingAnchor, constant: 3),
            closeTabButton.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor, constant: -7),
            closeTabButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            closeTabButton.widthAnchor.constraint(equalToConstant: 26),
            closeTabButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        moveTopEdge(of: editorView, below: tabBar, in: container)
        container.subviews.compactMap { $0 as? OverlayView }.forEach {
            moveTopEdge(of: $0, below: tabBar, in: container)
        }
        container.subviews.compactMap { $0 as? PopoverContainerView }.forEach {
            moveTopEdge(of: $0, below: tabBar, in: container, padding: 26)
        }
    }

    private func configureBarButton(_ button: NSButton, symbolName: String, toolTip: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
        button.imagePosition = .imageOnly
        button.bezelStyle = .accessoryBarAction
        button.showsBorderOnlyWhileMouseInside = true
        button.toolTip = toolTip
        button.target = self
        button.action = action
    }

    private func moveTopEdge(of child: NSView, below tabBar: NSView, in container: NSView, padding: CGFloat = 0) {
        let oldTopConstraints = container.constraints.filter { constraint in
            let firstItem = constraint.firstItem as AnyObject?
            let secondItem = constraint.secondItem as AnyObject?
            return constraint.firstAttribute == .top && constraint.secondAttribute == .top &&
                ((firstItem === child && secondItem === container) ||
                 (firstItem === container && secondItem === child))
        }
        NSLayoutConstraint.deactivate(oldTopConstraints)
        child.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: padding).isActive = true
    }

    private func refreshTabs() {
        tabStackView.arrangedSubviews.forEach {
            tabStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for (index, tab) in workspace.tabs.enumerated() {
            let button = NSButton(title: tab.title, target: self, action: #selector(selectTab(_:)))
            button.tag = index
            button.setButtonType(.pushOnPushOff)
            button.state = index == workspace.selectedIndex ? .on : .off
            button.bezelStyle = .accessoryBarAction
            button.lineBreakMode = .byTruncatingTail
            button.toolTip = tab.title
            button.widthAnchor.constraint(equalToConstant: 128).isActive = true
            tabStackView.addArrangedSubview(button)
        }

        tabStackView.frame = NSRect(x: 0, y: 0, width: CGFloat(workspace.tabs.count) * 132, height: 28)
        updateNumberedTabMenus()
    }

    private func installScratchpadMenus() {
        guard let mainMenu = NSApp.mainMenu,
              let fileMenu = mainMenu.item(withTitle: "File")?.submenu else { return }

        if let closeItem = fileMenu.items.first(where: { $0.keyEquivalent.lowercased() == "w" }) {
            closeItem.title = "Close Tab"
            closeItem.target = self
            closeItem.action = #selector(closeTab(_:))
        }

        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        newTabItem.target = self
        let renameItem = NSMenuItem(title: "Rename Tab…", action: #selector(renameTab(_:)), keyEquivalent: "")
        renameItem.target = self
        let moveLeftItem = NSMenuItem(title: "Move Tab Left", action: #selector(moveTabLeft(_:)), keyEquivalent: "")
        moveLeftItem.target = self
        let moveRightItem = NSMenuItem(title: "Move Tab Right", action: #selector(moveTabRight(_:)), keyEquivalent: "")
        moveRightItem.target = self

        fileMenu.insertItem(NSMenuItem.separator(), at: 0)
        fileMenu.insertItem(moveRightItem, at: 0)
        fileMenu.insertItem(moveLeftItem, at: 0)
        fileMenu.insertItem(renameItem, at: 0)
        fileMenu.insertItem(newTabItem, at: 0)

        guard let windowMenu = mainMenu.item(withTitle: "Window")?.submenu else { return }
        windowMenu.addItem(NSMenuItem.separator())
        numberedTabMenuItems = (0..<9).map { index in
            let item = NSMenuItem(title: "Tab \(index + 1)", action: #selector(selectNumberedTab(_:)), keyEquivalent: "\(index + 1)")
            item.keyEquivalentModifierMask = [.command]
            item.target = self
            item.tag = index
            windowMenu.addItem(item)
            return item
        }
        updateNumberedTabMenus()
    }

    private func updateNumberedTabMenus() {
        for (index, item) in numberedTabMenuItems.enumerated() {
            item.isHidden = !workspace.tabs.indices.contains(index)
            if workspace.tabs.indices.contains(index) {
                item.title = workspace.tabs[index].title
                item.state = index == workspace.selectedIndex ? .on : .off
            }
        }
    }

    @IBAction func openHelp(_ sender: Any) {
        open(url: "https://boop.okat.best/docs/")
    }
    
    
    @IBAction func openScripts(_ sender: Any) {
        open(url: "https://boop.okat.best/scripts/")
    }
    
    
    func open(url: String) {
        guard let url = URL(string: url) else {
            assertionFailure("Could not generate help URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func clear(_ sender: Any) {
        let textView = editorView.contentTextView
        textView.textStorage?.beginEditing()
        
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? textView.string.count)
        
        guard textView.shouldChangeText(in: range, replacementString: "") else {
            return
        }
        
        textView.textStorage?.replaceCharacters(in: range, with: "")
        
        textView.textStorage?.endEditing()
        textView.didChangeText()
    }
    
    
}

extension MainViewController: SyntaxTextViewDelegate {
    func theme(for appearance: NSAppearance) -> SyntaxColorTheme {
        return DefaultTheme(appearance: appearance)
    }
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        guard !isLoadingTab else { return }
        workspace.updateSelectedContent(syntaxTextView.contentTextView.string)
        scheduleSave()
    }
    
    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) {

    }
    
    func didChangeFont(_ font: Font) {
        //
    }
    
    func lexerForSource(_ source: String) -> Lexer {
        return BoopLexer()
    }
    
    
}
