//
//  ProwlMockEditorViewModel.swift
//  Prowl
//

import Foundation
import ProwlCore

enum ProwlMockEditorIntent {
    case save(urlPattern: String, method: String, statusCodeStr: String, delayMillisStr: String, bodyJSON: String)
    case cancel
}

@MainActor
final class ProwlMockEditorViewModel: ObservableObject {
    static let statusPresets = [200, 401, 404, 500, 503]

    let initialURLPattern: String
    let initialMethod: String
    let initialStatusCode: String
    let initialDelayMillis: String
    let initialBodyJSON: String
    let sourceURL: String?
    let existingRuleID: UUID?
    let isEditing: Bool

    @Published private(set) var isSaved = false

    init(log: NetworkLog) {
        sourceURL = log.url?.absoluteString
        initialURLPattern = Self.suggestedPattern(for: log.url)
        initialMethod = log.method.uppercased()
        initialStatusCode = String(log.statusCode ?? 200)
        initialDelayMillis = "0"
        initialBodyJSON = Self.suggestedBody(from: log.responseBody)
        existingRuleID = nil
        isEditing = false
    }

    init(rule: ProwlMockRule) {
        sourceURL = nil
        initialURLPattern = rule.targetURLPattern
        initialMethod = rule.targetMethod
        initialStatusCode = String(rule.mockStatusCode)
        initialDelayMillis = String(rule.responseDelayMillis)
        initialBodyJSON = rule.mockBodyText
        existingRuleID = rule.id
        isEditing = true
    }

    func handle(_ intent: ProwlMockEditorIntent) {
        switch intent {
        case let .save(urlPattern, method, statusCodeStr, delayMillisStr, bodyJSON):
            save(
                urlPattern: urlPattern,
                method: method,
                statusCodeStr: statusCodeStr,
                delayMillisStr: delayMillisStr,
                bodyJSON: bodyJSON
            )
        case .cancel:
            break
        }
    }

    private func save(
        urlPattern: String,
        method: String,
        statusCodeStr: String,
        delayMillisStr: String,
        bodyJSON: String
    ) {
        let code = Int(statusCodeStr) ?? 200
        let delay = min(max(Int(delayMillisStr) ?? 0, 0), 60_000)
        let data = bodyJSON.data(using: .utf8) ?? Data()

        let rule = ProwlMockRule(
            id: existingRuleID ?? UUID(),
            targetURLPattern: urlPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            targetMethod: method,
            mockStatusCode: code,
            mockBody: data,
            responseDelayMillis: delay,
            isEnabled: true
        )

        Task {
            await ProwlMocker.shared.saveRule(rule)
            isSaved = true
        }
    }

    private static func suggestedPattern(for url: URL?) -> String {
        guard let url else { return "" }
        guard let host = url.host else { return url.absoluteString }

        let path = url.path
        if path.isEmpty || path == "/" {
            return host
        }
        return "\(host)\(path)"
    }

    private static func suggestedBody(from body: NetworkLog.Body?) -> String {
        var defaultBody = """
        {
          "error": "Internal Server Error",
          "message": "Mocked response via Prowl"
        }
        """
        if let body,
           let text = String(data: body.data, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaultBody = text
        }
        return defaultBody
    }
}
