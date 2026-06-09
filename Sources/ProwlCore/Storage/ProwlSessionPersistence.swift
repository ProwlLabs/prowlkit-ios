//
//  ProwlSessionPersistence.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

package enum ProwlSessionPersistence {
    private static let fileName = "prowl_session.json"
    private static let enabledKey = "prowl_persist_sessions"

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    package static func restoreIfEmpty(into storage: ProwlStorage) async {
        guard isEnabled,
              let fileURL = sessionFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path),
              let json = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }
        let logs = NetworkLogSerializer.fromJSON(json)
        await storage.restoreIfEmpty(logs)
    }

    package static func persist(_ logs: [NetworkLog]) {
        guard isEnabled else { return }
        Task.detached(priority: .utility) {
            guard let fileURL = sessionFileURL() else { return }
            do {
                try ensureDirectory(for: fileURL)
                let json = NetworkLogSerializer.toJSON(logs)
                try json.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                // Best-effort persistence for debugger tooling.
            }
        }
    }

    package static func clear() {
        guard let fileURL = sessionFileURL() else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func sessionFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ProwlKit", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func ensureDirectory(for fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
