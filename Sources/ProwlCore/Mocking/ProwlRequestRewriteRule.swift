//
//  ProwlRequestRewriteRule.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct ProwlRequestRewriteRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var targetURLPattern: String
    public var targetMethod: String
    public var replacementURL: String
    public var headerOverrides: [String: String]
    public var headersToRemove: Set<String>
    public var replacementBody: Data?
    public var replacementContentType: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        targetURLPattern: String,
        targetMethod: String = "ANY",
        replacementURL: String = "",
        headerOverrides: [String: String] = [:],
        headersToRemove: Set<String> = [],
        replacementBody: Data? = nil,
        replacementContentType: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.targetURLPattern = targetURLPattern
        self.targetMethod = targetMethod
        self.replacementURL = replacementURL
        self.headerOverrides = headerOverrides
        self.headersToRemove = headersToRemove
        self.replacementBody = replacementBody
        self.replacementContentType = replacementContentType
        self.isEnabled = isEnabled
    }

    public var replacementBodyText: String? {
        replacementBody.flatMap { String(data: $0, encoding: .utf8) }
    }
}
