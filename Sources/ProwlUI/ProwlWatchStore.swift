//
//  ProwlWatchStore.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

@MainActor
enum ProwlWatchStore {
    private static let storageKey = "prowl_watch_endpoints"

    static func isWatched(_ log: NetworkLog) -> Bool {
        watchedPatterns().contains(log.endpointKey())
    }

    static func toggleWatch(for log: NetworkLog) {
        var patterns = watchedPatterns()
        let key = log.endpointKey()
        if patterns.contains(key) {
            patterns.remove(key)
        } else {
            patterns.insert(key)
        }
        UserDefaults.standard.set(Array(patterns), forKey: storageKey)
    }

    static func watchedPatterns() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }
}
