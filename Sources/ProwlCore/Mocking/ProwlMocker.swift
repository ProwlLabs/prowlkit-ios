//
//  ProwlMocker.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

/// A rule that intercepts matching requests and returns a synthetic HTTP response.
///
/// Matching is case-insensitive substring on the full URL string. Method must
/// match exactly unless ``targetMethod`` is `"ANY"`.
public struct ProwlMockRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var targetURLPattern: String
    public var targetMethod: String

    public var mockStatusCode: Int
    public var mockBody: Data
    public var mockHeaders: [String: String]

    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        targetURLPattern: String,
        targetMethod: String = "ANY",
        mockStatusCode: Int = 200,
        mockBody: Data = Data(),
        mockHeaders: [String: String] = ["Content-Type": "application/json"],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.targetURLPattern = targetURLPattern
        self.targetMethod = targetMethod
        self.mockStatusCode = mockStatusCode
        self.mockBody = mockBody
        self.mockHeaders = mockHeaders
        self.isEnabled = isEnabled
    }

    /// UTF-8 body text for display in the mock manager.
    public var mockBodyText: String {
        String(data: mockBody, encoding: .utf8) ?? ""
    }
}

public actor ProwlMocker {
    public static let shared = ProwlMocker()

    private var rules: [ProwlMockRule] = []

    public func addRule(_ rule: ProwlMockRule) {
        rules.append(rule)
    }

    public func updateRule(_ rule: ProwlMockRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }

    public func removeRule(id: UUID) {
        rules.removeAll(where: { $0.id == id })
    }

    public func removeAllRules() {
        rules.removeAll()
    }

    public func allRules() -> [ProwlMockRule] {
        rules
    }

    package func findMatch(for request: URLRequest) -> ProwlMockRule? {
        guard let urlStr = request.url?.absoluteString else { return nil }
        let method = request.httpMethod ?? "GET"

        return rules.first { rule in
            guard rule.isEnabled, !rule.targetURLPattern.isEmpty else { return false }
            guard urlStr.lowercased().contains(rule.targetURLPattern.lowercased()) else { return false }

            if !rule.targetMethod.isEmpty && rule.targetMethod.uppercased() != "ANY" {
                guard method.uppercased() == rule.targetMethod.uppercased() else { return false }
            }
            return true
        }
    }
}
