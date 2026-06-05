//
//  ProwlMockEditorViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

enum ProwlMockEditorIntent {
    case save(urlPattern: String, method: String, statusCodeStr: String, bodyJSON: String)
    case cancel
}

@MainActor
final class ProwlMockEditorViewModel: ObservableObject {
    static let statusPresets = [200, 401, 404, 500, 503]

    let initialURLPattern: String
    let initialMethod: String
    let initialBodyJSON: String
    let sourceURL: String?

    @Published private(set) var isSaved = false

    init(log: NetworkLog) {
        sourceURL = log.url?.absoluteString
        initialURLPattern = Self.suggestedPattern(for: log.url)
        initialMethod = log.method.uppercased()
        initialBodyJSON = Self.suggestedBody(from: log.responseBody)
    }

    func handle(_ intent: ProwlMockEditorIntent) {
        switch intent {
        case let .save(urlPattern, method, statusCodeStr, bodyJSON):
            save(urlPattern: urlPattern, method: method, statusCodeStr: statusCodeStr, bodyJSON: bodyJSON)
        case .cancel:
            break
        }
    }

    private func save(urlPattern: String, method: String, statusCodeStr: String, bodyJSON: String) {
        let code = Int(statusCodeStr) ?? 200
        let data = bodyJSON.data(using: .utf8) ?? Data()

        let rule = ProwlMockRule(
            targetURLPattern: urlPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            targetMethod: method,
            mockStatusCode: code,
            mockBody: data,
            isEnabled: true
        )

        Task {
            await ProwlMocker.shared.addRule(rule)
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
