//
//  BoopTests.swift
//  BoopTests
//
//  Created by Ivan on 3/21/20.
//

import XCTest

class BoopTests: XCTestCase {

    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testPersistenceRoundTripPreservesIDsTitlesContentOrderAndSelection() throws {
        let first = Scratchpad(title: "Request", content: "one")
        let second = Scratchpad(title: "Response", content: "two")
        let workspace = ScratchpadWorkspace(tabs: [first, second], selectedTabID: second.id)
        let store = ScratchpadWorkspaceStore(fileURL: temporaryDirectory.appendingPathComponent("workspace.json"))

        try store.save(workspace)

        XCTAssertEqual(store.load(), workspace)
    }

    func testFirstLaunchReturnsOneBlankScratchpad() {
        let store = ScratchpadWorkspaceStore(fileURL: temporaryDirectory.appendingPathComponent("missing.json"))

        let workspace = store.load()

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(selected(workspace).title, "Tab 1")
        XCTAssertEqual(selected(workspace).content, "")
    }

    func testCorruptedWorkspaceReturnsOneBlankScratchpad() throws {
        let url = temporaryDirectory.appendingPathComponent("workspace.json")
        try Data("not-json".utf8).write(to: url)

        let workspace = ScratchpadWorkspaceStore(fileURL: url).load()

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(selected(workspace).content, "")
    }

    func testStructurallyInvalidWorkspaceReturnsOneBlankScratchpad() throws {
        let url = temporaryDirectory.appendingPathComponent("workspace.json")
        let invalidWorkspace = """
        {
          "schemaVersion": 1,
          "tabs": [],
          "selectedTabID": "00000000-0000-0000-0000-000000000000"
        }
        """
        try Data(invalidWorkspace.utf8).write(to: url)

        let workspace = ScratchpadWorkspaceStore(fileURL: url).load()

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(selected(workspace).title, "Tab 1")
    }

    func testCreatingAndSelectingTabsKeepsContentIsolated() {
        var workspace = ScratchpadWorkspace()
        let first = workspace.tabs[0]
        workspace.updateContent("first", forTab: first.id)

        let second = workspace.createTab()
        XCTAssertEqual(second.title, "Tab 2")
        XCTAssertEqual(workspace.selectedTabID, second.id)
        workspace.updateContent("second", forTab: second.id)

        workspace.select(tabID: first.id)
        XCTAssertEqual(selected(workspace).content, "first")

        workspace.select(tabID: UUID())
        XCTAssertEqual(workspace.selectedTabID, first.id, "selecting an unknown tab is ignored")

        workspace.select(tabID: second.id)
        XCTAssertEqual(selected(workspace).content, "second")
    }

    // MARK: Operations by tab ID (one window per tab)

    func testUpdatingContentByIDOnlyTouchesThatTab() {
        let first = Scratchpad(title: "First", content: "one")
        let second = Scratchpad(title: "Second", content: "two")
        var workspace = ScratchpadWorkspace(tabs: [first, second], selectedTabID: first.id)

        workspace.updateContent("changed", forTab: second.id)

        XCTAssertEqual(workspace.tab(withID: first.id)?.content, "one")
        XCTAssertEqual(workspace.tab(withID: second.id)?.content, "changed")
        XCTAssertEqual(workspace.selectedTabID, first.id)
    }

    func testRemovingSelectedTabSelectsNeighbour() {
        let tabs = [Scratchpad(title: "A"), Scratchpad(title: "B"), Scratchpad(title: "C")]
        var workspace = ScratchpadWorkspace(tabs: tabs, selectedTabID: tabs[1].id)

        workspace.removeTab(id: tabs[1].id)

        XCTAssertEqual(workspace.tabs.map { $0.id }, [tabs[0].id, tabs[2].id])
        XCTAssertEqual(workspace.selectedTabID, tabs[2].id)
    }

    func testRemovingLastTabLeavesOneBlankTab() {
        let only = Scratchpad(title: "Only", content: "discard me")
        var workspace = ScratchpadWorkspace(tabs: [only])

        workspace.removeTab(id: only.id)

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertNotEqual(workspace.tabs[0].id, only.id)
        XCTAssertEqual(workspace.tabs[0].content, "")
        XCTAssertEqual(workspace.selectedTabID, workspace.tabs[0].id)
    }

    func testRenamingByIDTrimsAndIgnoresBlankTitles() {
        let tab = Scratchpad(title: "Old")
        var workspace = ScratchpadWorkspace(tabs: [tab])

        workspace.renameTab(id: tab.id, to: "  New  ")
        XCTAssertEqual(workspace.tab(withID: tab.id)?.title, "New")

        workspace.renameTab(id: tab.id, to: "   ")
        XCTAssertEqual(workspace.tab(withID: tab.id)?.title, "New")
    }

    func testReorderFollowsWindowOrderAndKeepsUnlistedTabs() {
        let tabs = [Scratchpad(title: "A"), Scratchpad(title: "B"), Scratchpad(title: "C")]
        var workspace = ScratchpadWorkspace(tabs: tabs)

        // C was dragged first; A is not listed (e.g. a minimized window)
        workspace.reorder(by: [tabs[2].id, tabs[1].id, UUID()])

        XCTAssertEqual(workspace.tabs.map { $0.title }, ["C", "B", "A"])
    }

    func testReorderKeepsSelection() {
        let tabs = [Scratchpad(title: "A"), Scratchpad(title: "B")]
        var workspace = ScratchpadWorkspace(tabs: tabs, selectedTabID: tabs[1].id)

        workspace.reorder(by: [tabs[1].id, tabs[0].id])

        XCTAssertEqual(workspace.tabs.map { $0.id }, [tabs[1].id, tabs[0].id])
        XCTAssertEqual(workspace.selectedTabID, tabs[1].id)
    }

    private func selected(_ workspace: ScratchpadWorkspace) -> Scratchpad {
        return workspace.tab(withID: workspace.selectedTabID)!
    }

}
