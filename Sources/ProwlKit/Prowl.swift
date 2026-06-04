//
//  Prowl.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
@_exported import ProwlCore
@_exported import ProwlUI

/// The main entry point for ProwlKit.
///
/// `Prowl` is the high-level facade that installs URL interception, manages
/// runtime configuration (storage, masking, ignore rules, rate alerts), and
/// drives the platform-specific inspector UI.
///
/// All members are isolated to the main actor — call them from the main thread
/// or inside a `@MainActor` context.
///
/// ## Typical usage
///
/// ```swift
/// import ProwlKit
///
/// @main
/// struct DemoApp: App {
///     init() {
///         Prowl.start()
///     }
///
///     var body: some Scene {
///         WindowGroup { ContentView() }
///     }
/// }
/// ```
@available(iOS 15, macOS 12, watchOS 8, tvOS 15, visionOS 1, *)
@MainActor
public enum Prowl {
    private static var isRunning = false
    private static let startupMessage = "Prowl Inspector started | Crafted by Elmee"

    /// The shared in-memory log store.
    ///
    /// Returns the current `ProwlStorage` instance held by the runtime.
    /// Replace it via ``configure(storage:masker:isLoggingEnabled:isSensitiveDataMaskingEnabled:)``.
    public static func storage() async -> ProwlStorage {
        await ProwlRuntime.shared.currentStorage()
    }

    /// URL substrings whose matching requests are excluded from interception.
    ///
    /// Use ``ignoreURL(_:)`` for additive updates or assign a fresh set here to
    /// replace the rule list.
    public static var ignoredURLs: Set<String> {
        get { ProwlRuntime.ignoredURLs }
        set { ProwlRuntime.ignoredURLs = newValue }
    }

    /// Regular-expression patterns whose matching requests are excluded from interception.
    ///
    /// Use ``ignoreURL(regex:)`` for additive updates or assign a fresh set here
    /// to replace the rule list.
    public static var ignoredURLRegexes: Set<String> {
        get { ProwlRuntime.ignoredURLRegexes }
        set { ProwlRuntime.ignoredURLRegexes = newValue }
    }

    /// Optional `URLSessionDelegate` used by the interception session.
    ///
    /// Set this to integrate certificate pinning, mTLS, or custom server-trust
    /// handling. Must be set before ``start(ignoredURLs:ignoredURLRegexes:)`` to
    /// affect new requests captured by Prowl.
    public static var customSessionDelegate: URLSessionDelegate? {
        get { ProwlRuntime.customSessionDelegate }
        set { ProwlRuntime.customSessionDelegate = newValue }
    }

    /// Whether `URLProtocol` interception is currently capturing requests.
    ///
    /// Set to `false` to pause logging without unregistering the protocol; set
    /// to `true` to resume. Default is `true`.
    public static var isLoggingEnabled: Bool {
        get { ProwlRuntime.isLoggingEnabled }
        set { ProwlRuntime.isLoggingEnabled = newValue }
    }

    /// Whether sensitive headers and JSON keys are redacted in stored logs.
    ///
    /// Default is `false` (raw values shown). Toggle to `true` for screen
    /// shares, demos, or production builds.
    public static var isSensitiveDataMaskingEnabled: Bool {
        get { ProwlRuntime.isSensitiveDataMaskingEnabled }
        set { ProwlRuntime.isSensitiveDataMaskingEnabled = newValue }
    }

    /// Optional transformer used to decode response bodies for display only.
    ///
    /// The live `URLSession` response is unchanged — this only affects what
    /// Prowl stores and renders. Useful for encrypted or binary payloads.
    public static var responseBodyLoggingTransformer: (any ProwlResponseBodyLoggingTransforming)? {
        get { ProwlRuntime.responseBodyLoggingTransformer }
        set { ProwlRuntime.responseBodyLoggingTransformer = newValue }
    }

    /// Rules that flag noisy endpoints when traffic crosses a threshold.
    ///
    /// Matches are keyed by HTTP method + host + path (query string is ignored).
    /// The request that hits the threshold has
    /// `NetworkLog.endpointRateAlertTriggered == true`.
    public static var endpointRateAlertRules: [ProwlEndpointRateAlertRule] {
        get { ProwlEndpointRateAlerts.rules }
        set { ProwlEndpointRateAlerts.rules = newValue }
    }

    /// Resets all per-rule counters back to zero.
    ///
    /// Counters reset automatically when you clear logs in the inspector.
    public static func resetEndpointRateAlertCounters() {
        ProwlEndpointRateAlerts.resetCounters()
    }

    /// Adds a URL substring to the ignore list.
    ///
    /// Convenience for inserting a single entry into ``ignoredURLs``.
    public static func ignoreURL(_ urlString: String) {
        ProwlRuntime.ignoredURLs.insert(urlString)
    }

    /// Adds a URL regex pattern to the ignore list.
    ///
    /// Convenience for inserting a single entry into ``ignoredURLRegexes``.
    public static func ignoreURL(regex pattern: String) {
        ProwlRuntime.ignoredURLRegexes.insert(pattern)
    }

    /// Configures storage, masker, and runtime flags before interception starts.
    ///
    /// Awaits the runtime actor so the configuration is in place before this
    /// call returns. Safe to invoke immediately before
    /// ``start(ignoredURLs:ignoredURLRegexes:)``.
    ///
    /// - Parameters:
    ///   - storage: Replaces the in-memory log store. Pass a configured
    ///     `ProwlStorage(limit:)` to change the FIFO buffer size.
    ///   - masker: Replaces the sensitive-data masker.
    ///   - isLoggingEnabled: When non-nil, pauses or resumes interception.
    ///   - isSensitiveDataMaskingEnabled: When non-nil, toggles masking.
    public static func configure(
        storage: ProwlStorage? = nil,
        masker: SensitiveDataMasker? = nil,
        isLoggingEnabled: Bool? = nil,
        isSensitiveDataMaskingEnabled: Bool? = nil
    ) async {
        await ProwlRuntime.shared.configure(
            storage: storage,
            masker: masker,
            isLoggingEnabled: isLoggingEnabled,
            isSensitiveDataMaskingEnabled: isSensitiveDataMaskingEnabled
        )
    }

    /// Starts URL interception and platform-specific inspector affordances.
    ///
    /// Idempotent — calling more than once is a no-op while interception is
    /// already active.
    ///
    /// - Parameters:
    ///   - ignoredURLs: URL substrings to add to the ignore list at startup.
    ///   - ignoredURLRegexes: Regex patterns to add to the ignore list at startup.
    public static func start(ignoredURLs: [String] = [], ignoredURLRegexes: [String] = []) {
        guard !isRunning else {
            log("\(startupMessage) (already running)")
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

        log(startupMessage)
    }

    /// Stops URL interception and tears down the inspector affordances.
    ///
    /// Existing logs in storage are retained. Idempotent — calling when
    /// already stopped is a no-op.
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

    /// Presents the inspector UI, starting interception first if needed.
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

    /// Dismisses the inspector UI.
    public static func hide() {
        guard isRunning else { return }
        #if os(iOS)
            ProwlAutoInspector.hide()
        #elseif os(macOS)
            ProwlMenuBarInspector.hide()
        #endif
    }

    /// Toggles the inspector UI, starting interception first if needed.
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

    private static func log(_ message: String) {
        NSLog("%@", message)
        print(message)
    }
}
