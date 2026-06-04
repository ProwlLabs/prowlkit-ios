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
    case save(urlPattern: String, statusCodeStr: String, bodyJSON: String)
    case cancel
}

@MainActor
final class ProwlMockEditorViewModel: ObservableObject {

    let initialURLPattern: String
    let initialBodyJSON: String

    @Published private(set) var isSaved = false

    init(log: NetworkLog) {
        initialURLPattern = log.url?.absoluteString ?? ""

        var defaultBody = #"{ "message": "Mocked via Prowl" }"#
        if let body = log.responseBody,
           let text = String(data: body.data, encoding: .utf8) {
            defaultBody = text
        }
        initialBodyJSON = defaultBody
    }

    func handle(_ intent: ProwlMockEditorIntent) {
        switch intent {
        case let .save(urlPattern, statusCodeStr, bodyJSON):
            save(urlPattern: urlPattern, statusCodeStr: statusCodeStr, bodyJSON: bodyJSON)
        case .cancel:
            break
        }
    }

    private func save(urlPattern: String, statusCodeStr: String, bodyJSON: String) {
        let code = Int(statusCodeStr) ?? 200
        let data = bodyJSON.data(using: .utf8) ?? Data()

        let rule = ProwlMockRule(
            targetURLPattern: urlPattern,
            targetMethod: "ANY",
            mockStatusCode: code,
            mockBody: data,
            isEnabled: true
        )

        Task {
            await ProwlMocker.shared.addRule(rule)
            isSaved = true
        }
    }
}
