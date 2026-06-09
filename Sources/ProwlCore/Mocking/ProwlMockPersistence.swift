//
//  ProwlMockPersistence.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

package enum ProwlMockPersistence {
    private static let fileName = "prowl_mock_rules.json"

    package static func restore(into mocker: ProwlMocker) async {
        guard let fileURL = rulesFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path),
              let json = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }
        let rules = ProwlMockExporter.importRules(json)
        await mocker.replaceAllRules(rules)
    }

    static func persist(_ rules: [ProwlMockRule]) {
        Task.detached(priority: .utility) {
            guard let fileURL = rulesFileURL() else { return }
            do {
                try ensureDirectory(for: fileURL)
                let json = ProwlMockExporter.exportRules(rules)
                try json.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                // Best-effort persistence for debugger tooling.
            }
        }
    }

    static func clear() {
        guard let fileURL = rulesFileURL() else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func rulesFileURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support
            .appendingPathComponent("ProwlKit", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func ensureDirectory(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
