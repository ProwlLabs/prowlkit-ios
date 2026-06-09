//
//  ProwlCore/Models/MultipartPart.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct MultipartPart: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(name ?? "")-\(fileName ?? "")-\(sizeBytes)" }
    public var name: String?
    public var fileName: String?
    public var contentType: String?
    public var headers: [String: String]
    public var sizeBytes: Int
    public var textPreview: String?
    public var isBinary: Bool

    public init(
        name: String? = nil,
        fileName: String? = nil,
        contentType: String? = nil,
        headers: [String: String] = [:],
        sizeBytes: Int = 0,
        textPreview: String? = nil,
        isBinary: Bool = false
    ) {
        self.name = name
        self.fileName = fileName
        self.contentType = contentType
        self.headers = headers
        self.sizeBytes = sizeBytes
        self.textPreview = textPreview
        self.isBinary = isBinary
    }
}
