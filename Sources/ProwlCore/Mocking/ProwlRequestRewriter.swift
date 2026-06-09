//
//  ProwlRequestRewriter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public actor ProwlRequestRewriter {
    public static let shared = ProwlRequestRewriter()

    private var rules: [ProwlRequestRewriteRule] = []
    private static let methodsWithoutBody: Set<String> = ["GET", "HEAD", "TRACE"]

    public func addRule(_ rule: ProwlRequestRewriteRule) {
        rules.append(rule)
        notifyChanged()
    }

    public func updateRule(_ rule: ProwlRequestRewriteRule) {
        saveRule(rule)
    }

    public func saveRule(_ rule: ProwlRequestRewriteRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        notifyChanged()
    }

    public func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
        notifyChanged()
    }

    public func removeAllRules() {
        rules.removeAll()
        ProwlRequestRewritePersistence.clear()
        publishRules()
    }

    public func replaceAllRules(_ newRules: [ProwlRequestRewriteRule]) {
        rules = newRules
        publishRules()
    }

    public func allRules() -> [ProwlRequestRewriteRule] {
        rules
    }

    package func findMatch(for request: URLRequest) -> ProwlRequestRewriteRule? {
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

    package func apply(to request: URLRequest, rule: ProwlRequestRewriteRule) -> URLRequest {
        var mutable = request

        let replacement = rule.replacementURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !replacement.isEmpty {
            if replacement.contains("://"), let url = URL(string: replacement) {
                mutable.url = url
            } else if let originalURL = request.url {
                var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
                let path = replacement.hasPrefix("/") ? replacement : "/\(replacement)"
                if let queryIndex = path.firstIndex(of: "?") {
                    components?.path = String(path[..<queryIndex])
                    components?.percentEncodedQuery = String(path[path.index(after: queryIndex)...])
                } else {
                    components?.path = path
                }
                if let newURL = components?.url {
                    mutable.url = newURL
                }
            }
        }

        for header in rule.headersToRemove {
            mutable.setValue(nil, forHTTPHeaderField: header)
        }
        for (name, value) in rule.headerOverrides {
            mutable.setValue(value, forHTTPHeaderField: name)
        }

        if let bodyBytes = rule.replacementBody {
            let method = (request.httpMethod ?? "GET").uppercased()
            if !Self.methodsWithoutBody.contains(method) {
                mutable.httpBody = bodyBytes
                if let contentType = rule.replacementContentType {
                    mutable.setValue(contentType, forHTTPHeaderField: "Content-Type")
                }
            }
        }

        return mutable
    }

    private func notifyChanged() {
        ProwlRequestRewritePersistence.persist(rules)
        publishRules()
    }

    private func publishRules() {
        NotificationCenter.default.post(name: .prowlRewriteRulesDidChange, object: nil)
    }
}
