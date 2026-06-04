//
//  ProwlLogDetailViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum ProwlBodyRenderable: Sendable {
    case text(AttributedString)
    case image(Data)
    case empty
}

enum ProwlLogDetailIntent {
    case togglePrettyPrint
    case copyBody(isRequest: Bool)
    case shareJSON
    case shareCURL
}


@MainActor
final class ProwlLogDetailViewModel: ObservableObject {

    @Published private(set) var requestBody: ProwlBodyRenderable = .empty
    @Published private(set) var responseBody: ProwlBodyRenderable = .empty
    @Published private(set) var isPretty: Bool = true
    @Published private(set) var shareContent: String? = nil
    @Published private(set) var pasteboardString: String? = nil

    private let log: NetworkLog

    init(log: NetworkLog) {
        self.log = log
        recompute()
    }

    func handle(_ intent: ProwlLogDetailIntent) {
        switch intent {
        case .togglePrettyPrint:
            isPretty.toggle()
            recompute()

        case .copyBody(let isRequest):
            let body = isRequest ? log.requestBody : log.responseBody
            guard let body else { return }
            pasteboardString = ProwlLogFormatter.bodyText(from: body, pretty: isPretty)

        case .shareJSON:
            // Force value transition so the view receives change events
            // even when the generated payload is identical to previous share.
            shareContent = nil
            shareContent = buildJSONShare()

        case .shareCURL:
            shareContent = nil
            shareContent = ProwlLogFormatter.export(logs: [log], as: .curlCommands)
        }
    }

    private func recompute() {
        requestBody = resolve(log.requestBody)
        responseBody = resolve(log.responseBody)
    }

    private func resolve(_ body: NetworkLog.Body?) -> ProwlBodyRenderable {
        guard let body, !body.data.isEmpty else { return .empty }

        let isImage = body.contentType?.lowercased().contains("image") ?? false
        if isImage { return .image(body.data) }

        let text = ProwlLogFormatter.bodyText(from: body, pretty: isPretty)
        let attributed = ProwlJSONSyntaxHighlighter.highlight(text, contentType: body.contentType)
        return .text(attributed)
    }

    private func buildJSONShare() -> String? {
        ProwlLogFormatter.shareText(log: log)
    }
}
