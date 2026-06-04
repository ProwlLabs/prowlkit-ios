//
//  ProwlRuntime.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

package actor ProwlRuntime {
    package static let shared = ProwlRuntime()
    
    nonisolated(unsafe) package static var ignoredURLs: Set<String> = []
    nonisolated(unsafe) package static var ignoredURLRegexes: Set<String> = []
    nonisolated(unsafe) package static var customSessionDelegate: URLSessionDelegate? = nil
    nonisolated(unsafe) package static var isLoggingEnabled: Bool = true
    nonisolated(unsafe) package static var isSensitiveDataMaskingEnabled: Bool = false
    nonisolated(unsafe) package static var responseBodyLoggingTransformer: (any ProwlResponseBodyLoggingTransforming)?

    private var storage: ProwlStorage
    private var masker: SensitiveDataMasker

    package init(
        storage: ProwlStorage = .init(),
        masker: SensitiveDataMasker = .init()
    ) {
        self.storage = storage
        self.masker = masker
    }

    package func configure(
        storage: ProwlStorage? = nil,
        masker: SensitiveDataMasker? = nil,
        isLoggingEnabled: Bool? = nil,
        isSensitiveDataMaskingEnabled: Bool? = nil
    ) {
        if let storage {
            self.storage = storage
        }
        if let masker {
            self.masker = masker
        }
        if let isLoggingEnabled {
            Self.isLoggingEnabled = isLoggingEnabled
        }
        if let isSensitiveDataMaskingEnabled {
            Self.isSensitiveDataMaskingEnabled = isSensitiveDataMaskingEnabled
        }
    }

    package nonisolated static func shouldIgnore(_ absoluteURLString: String) -> Bool {
        if ignoredURLs.contains(where: { absoluteURLString.contains($0) }) {
            return true
        }

        for pattern in ignoredURLRegexes {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let range = NSRange(location: 0, length: absoluteURLString.utf16.count)
            if regex.firstMatch(in: absoluteURLString, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    package nonisolated static func installRequestBodySnapshotSupportIfNeeded() {
        #if canImport(ObjectiveC)
        ProwlURLSessionBodySnapshotInstaller.installIfNeeded()
        #endif
    }

    package func snapshot() -> (storage: ProwlStorage, masker: SensitiveDataMasker) {
        (storage, masker)
    }

    package func currentStorage() -> ProwlStorage {
        storage
    }
}
