//
//  ScratchpadWorkspaceStore.swift
//  Boop
//

import Foundation

final class ScratchpadWorkspaceStore {
    static let directoryName = "Boop"
    static let fileName = "Scratchpads.json"

    let fileURL: URL

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL = fileURL {
            self.fileURL = fileURL
            return
        }

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = applicationSupportURL
            .appendingPathComponent(ScratchpadWorkspaceStore.directoryName, isDirectory: true)
            .appendingPathComponent(ScratchpadWorkspaceStore.fileName, isDirectory: false)
    }

    func load() -> ScratchpadWorkspace {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ScratchpadWorkspace.self, from: data).validated()
        } catch {
            return ScratchpadWorkspace()
        }
    }

    func save(_ workspace: ScratchpadWorkspace, fileManager: FileManager = .default) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(workspace.validated()).write(to: fileURL, options: .atomic)
    }
}
