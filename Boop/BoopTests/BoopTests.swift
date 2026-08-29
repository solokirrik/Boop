//
//  BoopTests.swift
//  BoopTests
//
//  Created by Ivan on 3/21/20.
//  Copyright © 2020 OKatBest. All rights reserved.
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
        XCTAssertEqual(workspace.selectedTab.title, "Tab 1")
        XCTAssertEqual(workspace.selectedTab.content, "")
    }

    func testCorruptedWorkspaceReturnsOneBlankScratchpad() throws {
        let url = temporaryDirectory.appendingPathComponent("workspace.json")
        try Data("not-json".utf8).write(to: url)

        let workspace = ScratchpadWorkspaceStore(fileURL: url).load()

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(workspace.selectedTab.content, "")
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
        XCTAssertEqual(workspace.selectedTab.title, "Tab 1")
    }

    func testClosingLastTabKeepsOneBlankScratchpad() {
        var workspace = ScratchpadWorkspace(tabs: [Scratchpad(content: "discard me")])

        workspace.closeSelectedTab()

        XCTAssertEqual(workspace.tabs.count, 1)
        XCTAssertEqual(workspace.selectedTab.content, "")
    }

    func testTabContentStaysIsolatedWhenSwitching() {
        var workspace = ScratchpadWorkspace()
        workspace.updateSelectedContent("first")
        workspace.createTab()
        workspace.updateSelectedContent("second")

        workspace.selectTab(at: 0)
        XCTAssertEqual(workspace.selectedTab.content, "first")

        workspace.selectTab(at: 1)
        XCTAssertEqual(workspace.selectedTab.content, "second")
    }

    func testMovingTabPersistsItsOrdering() {
        let first = Scratchpad(title: "First")
        let second = Scratchpad(title: "Second")
        var workspace = ScratchpadWorkspace(tabs: [first, second], selectedTabID: second.id)

        workspace.moveSelectedTab(by: -1)

        XCTAssertEqual(workspace.tabs.map { $0.id }, [second.id, first.id])
        XCTAssertEqual(workspace.selectedTabID, second.id)
    }

}
