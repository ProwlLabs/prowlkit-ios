//
//  Prowl.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore
@_exported import ProwlUI

@MainActor
public enum Prowl {
    public static let version = "1.0.0"

    private static var isRunning = false
    private static let startupMessage = "Prowl Inspector started | Crafted by Elmee"

    public static func storage() async -> ProwlStorage {
        await ProwlRuntime.shared.currentStorage()
    }

    public static var ignoredURLs: Set<String> {
        get { ProwlRuntime.ignoredURLs }
        set { ProwlRuntime.ignoredURLs = newValue }
    }

    public static var ignoredURLRegexes: Set<String> {
        get { ProwlRuntime.ignoredURLRegexes }
        set { ProwlRuntime.ignoredURLRegexes = newValue }
    }
    
    public static var customSessionDelegate: URLSessionDelegate? {
        get { ProwlRuntime.customSessionDelegate }
        set { ProwlRuntime.customSessionDelegate = newValue }
    }

    public static var isLoggingEnabled: Bool {
        get { ProwlRuntime.isLoggingEnabled }
        set { ProwlRuntime.isLoggingEnabled = newValue }
    }

    public static var isSensitiveDataMaskingEnabled: Bool {
        get { ProwlRuntime.isSensitiveDataMaskingEnabled }
        set { ProwlRuntime.isSensitiveDataMaskingEnabled = newValue }
    }

    public static var responseBodyLoggingTransformer: (any ProwlResponseBodyLoggingTransforming)? {
        get { ProwlRuntime.responseBodyLoggingTransformer }
        set { ProwlRuntime.responseBodyLoggingTransformer = newValue }
    }

    public static var endpointRateAlertRules: [ProwlEndpointRateAlertRule] {
        get { ProwlEndpointRateAlerts.rules }
        set { ProwlEndpointRateAlerts.rules = newValue }
    }

    public static func resetEndpointRateAlertCounters() {
        ProwlEndpointRateAlerts.resetCounters()
    }

    public static func ignoreURL(_ urlString: String) {
        ProwlRuntime.ignoredURLs.insert(urlString)
    }

    public static func ignoreURL(regex pattern: String) {
        ProwlRuntime.ignoredURLRegexes.insert(pattern)
    }

    public static func start(ignoredURLs: [String] = [], ignoredURLRegexes: [String] = []) {
        guard !isRunning else {
            log("[\(version)] \(startupMessage) (already running)")
            return
        }

        ignoredURLs.forEach { ignoreURL($0) }
        ignoredURLRegexes.forEach { ignoreURL(regex: $0) }

        ProwlRuntime.installRequestBodySnapshotSupportIfNeeded()
        URLProtocol.registerClass(ProwlProtocol.self)
        #if os(iOS)
            ProwlAutoInspector.enable()
        #elseif os(macOS)
            ProwlMenuBarInspector.enable()
        #endif
        isRunning = true

        log("[\(version)] \(startupMessage)")
    }

    public static func stop() {
        guard isRunning else { return }
        URLProtocol.unregisterClass(ProwlProtocol.self)
        #if os(iOS)
            ProwlAutoInspector.disable()
        #elseif os(macOS)
            ProwlMenuBarInspector.disable()
        #endif
        isRunning = false
    }

    public static func show() {
        if !isRunning {
            start()
        }
        #if os(iOS)
            ProwlAutoInspector.show()
        #elseif os(macOS)
            ProwlMenuBarInspector.show()
        #endif
    }

    public static func hide() {
        guard isRunning else { return }
        #if os(iOS)
            ProwlAutoInspector.hide()
        #elseif os(macOS)
            ProwlMenuBarInspector.hide()
        #endif
    }

    public static func toggle() {
        if !isRunning {
            start()
        }
        #if os(iOS)
            ProwlAutoInspector.toggle()
        #elseif os(macOS)
            ProwlMenuBarInspector.toggle()
        #endif
    }

    public static func configure(
        storage: ProwlStorage? = nil,
        masker: SensitiveDataMasker? = nil,
        isLoggingEnabled: Bool? = nil,
        isSensitiveDataMaskingEnabled: Bool? = nil
    ) {
        Task {
            await ProwlRuntime.shared.configure(
                storage: storage,
                masker: masker,
                isLoggingEnabled: isLoggingEnabled,
                isSensitiveDataMaskingEnabled: isSensitiveDataMaskingEnabled
            )
        }
    }

    private static func log(_ message: String) {
        NSLog("%@", message)
        print(message)
    }
}
