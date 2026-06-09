//
//  ProwlRequestRewriteEditorViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

@MainActor
final class ProwlRequestRewriteEditorViewModel: ObservableObject {
    let initialURLPattern: String
    let initialMethod: String
    let initialReplacementURL: String
    let initialHeaderOverrides: String
    let initialHeadersToRemove: String
    let initialBody: String
    let initialContentType: String
    let initialReplaceBody: Bool
    let sourceURL: String?

    @Published private(set) var isSaved = false

    init(log: NetworkLog) {
        sourceURL = log.url?.absoluteString
        initialURLPattern = Self.suggestedPattern(for: log.url)
        initialMethod = log.method.uppercased()
        initialReplacementURL = ""
        initialHeaderOverrides = log.requestHeaders
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
        initialHeadersToRemove = ""
        if let body = log.requestBody,
           let text = String(data: body.data, encoding: .utf8),
           !text.isEmpty {
            initialBody = text
            initialReplaceBody = true
            initialContentType = body.contentType ?? "application/json"
        } else {
            initialBody = ""
            initialReplaceBody = false
            initialContentType = "application/json"
        }
    }

    func save(
        urlPattern: String,
        method: String,
        replacementURL: String,
        headerOverridesText: String,
        headersToRemoveText: String,
        bodyText: String,
        contentType: String,
        replaceBody: Bool
    ) {
        let overrides = Self.parseHeaderLines(headerOverridesText)
        let headersToRemove = Set(
            headersToRemoveText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let rule = ProwlRequestRewriteRule(
            targetURLPattern: urlPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            targetMethod: method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ANY" : method,
            replacementURL: replacementURL.trimmingCharacters(in: .whitespacesAndNewlines),
            headerOverrides: overrides,
            headersToRemove: headersToRemove,
            replacementBody: replaceBody ? (bodyText.data(using: .utf8) ?? Data()) : nil,
            replacementContentType: replaceBody
                ? (contentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "application/json" : contentType)
                : nil,
            isEnabled: true
        )

        Task {
            await ProwlRequestRewriter.shared.saveRule(rule)
            isSaved = true
        }
    }

    private static func suggestedPattern(for url: URL?) -> String {
        guard let url else { return "" }
        guard let host = url.host else { return url.absoluteString }
        let path = url.path
        if path.isEmpty || path == "/" { return host }
        return "\(host)\(path)"
    }

    private static func parseHeaderLines(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let idx = trimmed.firstIndex(of: ":") else { continue }
            let name = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            result[name] = value
        }
        return result
    }
}
