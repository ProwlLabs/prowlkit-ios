//
//  ProwlSearchParser.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct ProwlSearchQuery: Sendable {
    public var method: String?
    public var statusCode: Int?
    public var statusRange: ClosedRange<Int>?
    public var hostContains: String?
    public var freeTextTokens: [String] = []

    public init(
        method: String? = nil,
        statusCode: Int? = nil,
        statusRange: ClosedRange<Int>? = nil,
        hostContains: String? = nil,
        freeTextTokens: [String] = []
    ) {
        self.method = method
        self.statusCode = statusCode
        self.statusRange = statusRange
        self.hostContains = hostContains
        self.freeTextTokens = freeTextTokens
    }
}

public enum ProwlSearchParser {
    public static func parse(_ raw: String) -> ProwlSearchQuery {
        var query = ProwlSearchQuery()
        for token in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            if token.lowercased().hasPrefix("method:") {
                query.method = String(token.dropFirst("method:".count)).uppercased()
            } else if token.lowercased().hasPrefix("status:") {
                let value = String(token.dropFirst("status:".count))
                if value.hasSuffix("xx"), let first = value.first, let digit = Int(String(first)) {
                    query.statusRange = (digit * 100)...((digit * 100) + 99)
                } else if let code = Int(value) {
                    query.statusCode = code
                }
            } else if token.lowercased().hasPrefix("host:") {
                query.hostContains = String(token.dropFirst("host:".count))
            } else if !token.isEmpty {
                query.freeTextTokens.append(token)
            }
        }
        return query
    }

    public static func matches(_ log: NetworkLog, query: ProwlSearchQuery) -> Bool {
        if let method = query.method, log.method.uppercased() != method { return false }
        if let code = query.statusCode, log.statusCode != code { return false }
        if let range = query.statusRange {
            guard let status = log.statusCode, range.contains(status) else { return false }
        }
        if let host = query.hostContains {
            let hostValue = log.url?.host ?? ""
            if hostValue.range(of: host, options: .caseInsensitive) == nil { return false }
        }
        guard !query.freeTextTokens.isEmpty else { return true }

        let haystack = searchableText(for: log).lowercased()
        return query.freeTextTokens.allSatisfy { haystack.contains($0.lowercased()) }
    }

    private static func searchableText(for log: NetworkLog) -> String {
        var parts: [String] = [
            log.url?.absoluteString ?? "",
            log.method,
            log.statusCode.map(String.init) ?? "",
            log.hostIp ?? "",
        ]
        parts.append(contentsOf: log.requestHeaders.values)
        parts.append(contentsOf: log.responseHeaders.values)
        if let body = log.requestBody {
            parts.append(ProwlBodyDecoder.toText(
                data: body.data,
                contentType: body.contentType,
                contentEncoding: log.requestHeaders["Content-Encoding"]
            ))
        }
        if let body = log.responseBody {
            parts.append(ProwlBodyDecoder.toText(
                data: body.data,
                contentType: body.contentType,
                contentEncoding: log.responseHeaders["Content-Encoding"]
            ))
        }
        return parts.joined(separator: "\n")
    }
}
