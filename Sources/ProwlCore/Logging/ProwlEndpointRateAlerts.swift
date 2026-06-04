//
//  ProwlEndpointRateAlerts.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

/// A rule that flags an endpoint when request volume crosses a threshold.
///
/// Evaluation keys requests by HTTP method + host + path (query is ignored).
/// The request whose count reaches ``threshold`` sets
/// ``NetworkLog/endpointRateAlertTriggered`` to `true`.
///
/// Assign rules via `Prowl.endpointRateAlertRules` or ``ProwlEndpointRateAlerts/rules``.
public struct ProwlEndpointRateAlertRule: Sendable, Hashable, Identifiable {
    /// How a rule selects matching traffic.
    public enum Match: Sendable, Hashable {
        /// Absolute URL string must contain this fragment.
        case urlContains(String)
        /// Absolute URL string must match this regular expression.
        case urlRegularExpression(pattern: String)
    }

    /// Stable identifier for this rule.
    public let id: UUID
    /// Match predicate applied to each captured request URL.
    public let match: Match
    /// Number of matching requests before the alert fires (minimum `1`).
    public let threshold: Int

    /// Creates a rule with a match predicate and hit count.
    ///
    /// - Parameters:
    ///   - id: Unique rule id. Defaults to a new `UUID`.
    ///   - match: Substring or regex match against the absolute URL string.
    ///   - threshold: Inclusive count at which the alert triggers.
    public init(id: UUID = UUID(), match: Match, threshold: Int) {
        self.id = id
        self.match = match
        self.threshold = max(1, threshold)
    }
}

/// Global coordinator for endpoint rate-alert rules and per-rule counters.
///
/// Prefer `Prowl.endpointRateAlertRules` and `Prowl.resetEndpointRateAlertCounters()`
/// in app code; this type is the lower-level hook used by the runtime.
public enum ProwlEndpointRateAlerts {

    /// Active rules, in insertion order.
    public static var rules: [ProwlEndpointRateAlertRule] {
        get { ProwlEndpointRateAlertCoordinator.shared.rules }
        set { ProwlEndpointRateAlertCoordinator.shared.rules = newValue }
    }

    /// Clears all per-rule hit counters without removing rules.
    public static func resetCounters() {
        ProwlEndpointRateAlertCoordinator.shared.reset()
    }
}

final class ProwlEndpointRateAlertCoordinator: @unchecked Sendable {
    static let shared = ProwlEndpointRateAlertCoordinator()

    private let lock = NSLock()
    private var rulesStorage: [UUID: ProwlEndpointRateAlertRule] = [:]
    private var orderedRuleIDs: [UUID] = []
    private var counts: [String: Int] = [:]

    private init() {}

    var rules: [ProwlEndpointRateAlertRule] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return orderedRuleIDs.compactMap { rulesStorage[$0] }
        }
        set {
            lock.lock()
            rulesStorage = Dictionary(uniqueKeysWithValues: newValue.map { ($0.id, $0) })
            orderedRuleIDs = newValue.map(\.id)
            counts.removeAll(keepingCapacity: true)
            lock.unlock()
        }
    }

    func reset() {
        lock.lock()
        counts.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func evaluateAndIncrement(method: String, url: URL?, absoluteURLString: String) -> Bool {
        lock.lock()
        let snapshotRules = orderedRuleIDs.compactMap { rulesStorage[$0] }
        lock.unlock()

        guard snapshotRules.isEmpty == false else { return false }

        let signature = Self.endpointSignature(method: method, url: url)
        var fired = false

        lock.lock()
        defer { lock.unlock() }

        for rule in snapshotRules {
            guard matches(rule.match, absoluteURLString: absoluteURLString) else { continue }
            let key = "\(rule.id.uuidString)|\(signature)"
            let next = (counts[key] ?? 0) + 1
            counts[key] = next
            if next == rule.threshold {
                fired = true
            }
        }

        return fired
    }

    private static func endpointSignature(method: String, url: URL?) -> String {
        guard let url else { return "\(method.uppercased())|" }
        let host = url.host ?? ""
        let path = url.path.isEmpty ? "/" : url.path
        return "\(method.uppercased())|\(host)\(path)"
    }

    private func matches(_ match: ProwlEndpointRateAlertRule.Match, absoluteURLString: String) -> Bool {
        switch match {
        case .urlContains(let fragment):
            return absoluteURLString.contains(fragment)
        case .urlRegularExpression(let pattern):
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return false
            }
            let range = NSRange(location: 0, length: absoluteURLString.utf16.count)
            return regex.firstMatch(in: absoluteURLString, options: [], range: range) != nil
        }
    }
}
