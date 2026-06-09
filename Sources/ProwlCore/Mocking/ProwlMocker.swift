//
//  ProwlMocker.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct ProwlMockRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var targetURLPattern: String
    public var targetMethod: String
    public var mockStatusCode: Int
    public var mockBody: Data
    public var mockHeaders: [String: String]
    public var responseDelayMillis: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        targetURLPattern: String,
        targetMethod: String = "ANY",
        mockStatusCode: Int = 200,
        mockBody: Data = Data(),
        mockHeaders: [String: String] = ["Content-Type": "application/json"],
        responseDelayMillis: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.targetURLPattern = targetURLPattern
        self.targetMethod = targetMethod
        self.mockStatusCode = mockStatusCode
        self.mockBody = mockBody
        self.mockHeaders = mockHeaders
        self.responseDelayMillis = max(0, responseDelayMillis)
        self.isEnabled = isEnabled
    }

    public var mockBodyText: String {
        String(data: mockBody, encoding: .utf8) ?? ""
    }
}

public actor ProwlMocker {
    public static let shared = ProwlMocker()

    private var rules: [ProwlMockRule] = []

    public func addRule(_ rule: ProwlMockRule) {
        saveRule(rule)
    }

    public func updateRule(_ rule: ProwlMockRule) {
        saveRule(rule)
    }

    public func saveRule(_ rule: ProwlMockRule) {
        if let byID = rules.firstIndex(where: { $0.id == rule.id }) {
            if let duplicate = rules.firstIndex(where: {
                Self.hasSameMatchKey($0, rule) && $0.id != rule.id
            }) {
                rules.remove(at: duplicate)
            }
            rules[byID] = rule
        } else if let byKey = rules.firstIndex(where: { Self.hasSameMatchKey($0, rule) }) {
            rules[byKey] = rule
        } else {
            rules.append(rule)
        }
        notifyChanged()
    }

    public func moveRuleUp(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }), index > 0 else { return }
        rules.swapAt(index, index - 1)
        notifyChanged()
    }

    public func moveRuleDown(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }), index < rules.count - 1 else { return }
        rules.swapAt(index, index + 1)
        notifyChanged()
    }

    public func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        notifyChanged()
    }

    public func removeAllRules() {
        rules.removeAll()
        ProwlMockPersistence.clear()
        publishRules()
    }

    public func replaceAllRules(_ newRules: [ProwlMockRule]) {
        rules = newRules
        publishRules()
    }

    public func allRules() -> [ProwlMockRule] {
        rules
    }

    package func findMatch(for request: URLRequest) -> ProwlMockRule? {
        let urlStr = request.url?.absoluteString
        let method = request.httpMethod ?? "GET"
        return rules.first { rule in
            ProwlRuleMatcher.matches(
                url: urlStr,
                method: method,
                targetURLPattern: rule.targetURLPattern,
                targetMethod: rule.targetMethod,
                isEnabled: rule.isEnabled
            )
        }
    }

    private func notifyChanged() {
        ProwlMockPersistence.persist(rules)
        publishRules()
    }

    private func publishRules() {
        NotificationCenter.default.post(name: .prowlMockRulesDidChange, object: nil)
    }

    private static func hasSameMatchKey(_ a: ProwlMockRule, _ b: ProwlMockRule) -> Bool {
        a.targetURLPattern.caseInsensitiveCompare(b.targetURLPattern) == .orderedSame
            && a.targetMethod.caseInsensitiveCompare(b.targetMethod) == .orderedSame
    }
}
