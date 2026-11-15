//
//  ScratchpadWorkspace.swift
//  Boop
//

import Foundation

struct Scratchpad: Codable, Equatable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String = "Tab 1", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
    }
}

struct ScratchpadWorkspace: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    private(set) var tabs: [Scratchpad]
    private(set) var selectedTabID: UUID

    init(tabs: [Scratchpad] = [Scratchpad()], selectedTabID: UUID? = nil) {
        let safeTabs = tabs.isEmpty ? [Scratchpad()] : tabs
        self.schemaVersion = ScratchpadWorkspace.currentSchemaVersion
        self.tabs = safeTabs
        self.selectedTabID = selectedTabID.flatMap { id in
            safeTabs.contains(where: { $0.id == id }) ? id : nil
        } ?? safeTabs[0].id
    }

    var selectedIndex: Int {
        return tabs.firstIndex(where: { $0.id == selectedTabID }) ?? 0
    }

    var selectedTab: Scratchpad {
        return tabs[selectedIndex]
    }

    func validated() throws -> ScratchpadWorkspace {
        guard schemaVersion == ScratchpadWorkspace.currentSchemaVersion,
              !tabs.isEmpty,
              Set(tabs.map { $0.id }).count == tabs.count,
              tabs.contains(where: { $0.id == selectedTabID }),
              tabs.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ScratchpadWorkspaceError.invalidWorkspace
        }
        var normalized = self
        for index in normalized.tabs.indices {
            let title = normalized.tabs[index].title
            if title == "Scratchpad" {
                normalized.tabs[index].title = "Tab 1"
            } else if title.hasPrefix("Scratchpad "),
                      let number = Int(title.dropFirst("Scratchpad ".count)) {
                normalized.tabs[index].title = "Tab \(number)"
            }
        }
        return normalized
    }

    mutating func updateSelectedContent(_ content: String) {
        tabs[selectedIndex].content = content
    }

    @discardableResult
    mutating func createTab() -> Scratchpad {
        let tab = Scratchpad(title: nextTabTitle())
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    mutating func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedTabID = tabs[index].id
    }

    mutating func renameSelectedTab(to title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        tabs[selectedIndex].title = trimmedTitle
    }

    mutating func closeSelectedTab() {
        let closingIndex = selectedIndex

        if tabs.count == 1 {
            let replacement = Scratchpad()
            tabs = [replacement]
            selectedTabID = replacement.id
            return
        }

        tabs.remove(at: closingIndex)
        selectedTabID = tabs[min(closingIndex, tabs.count - 1)].id
    }

    mutating func moveSelectedTab(by offset: Int) {
        let oldIndex = selectedIndex
        let newIndex = oldIndex + offset
        guard tabs.indices.contains(newIndex) else { return }
        tabs.swapAt(oldIndex, newIndex)
    }

    // MARK: Operations by tab ID (one window per tab)

    func tab(withID id: UUID) -> Scratchpad? {
        return tabs.first(where: { $0.id == id })
    }

    mutating func select(tabID id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    mutating func updateContent(_ content: String, forTab id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].content = content
    }

    mutating func renameTab(id: UUID, to title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].title = trimmedTitle
    }

    /// Removes a tab. Removing the last one leaves a single blank tab.
    mutating func removeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard tabs.count > 1 else {
            let replacement = Scratchpad()
            tabs = [replacement]
            selectedTabID = replacement.id
            return
        }
        tabs.remove(at: index)
        if selectedTabID == id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    /// Reorders tabs to match `ids`; unknown IDs are ignored, missing tabs keep their relative order at the end.
    mutating func reorder(by ids: [UUID]) {
        let position = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let indexed = tabs.enumerated().map { ($0, $1) }
        tabs = indexed.sorted { lhs, rhs in
            let left = position[lhs.1.id] ?? (ids.count + lhs.0)
            let right = position[rhs.1.id] ?? (ids.count + rhs.0)
            return left < right
        }.map { $0.1 }
    }

    private func nextTabTitle() -> String {
        let usedTitles = Set(tabs.map { $0.title })
        var number = 1
        while usedTitles.contains("Tab \(number)") {
            number += 1
        }
        return "Tab \(number)"
    }
}

enum ScratchpadWorkspaceError: Error {
    case invalidWorkspace
}
