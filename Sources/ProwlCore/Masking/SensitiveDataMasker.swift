//
//  SensitiveDataMasker.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public struct SensitiveDataMasker: Sendable {
    public static let defaultSensitiveHeaders: Set<String> = [
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
        "x-auth-token"
    ]

    public static let defaultSensitiveJSONKeys: Set<String> = [
        "password",
        "passcode",
        "token",
        "access_token",
        "refresh_token",
        "id_token",
        "bearer",
        "authorization",
        "cookie",
        "private_key",
        "privatekey",
        "client_secret",
        "secret"
    ]

    public let sensitiveHeaders: Set<String>
    public let sensitiveJSONKeys: Set<String>
    public let redactionToken: String

    public init(
        sensitiveHeaders: Set<String> = Self.defaultSensitiveHeaders,
        sensitiveJSONKeys: Set<String> = Self.defaultSensitiveJSONKeys,
        redactionToken: String = "[REDACTED]"
    ) {
        self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
        self.sensitiveJSONKeys = Set(sensitiveJSONKeys.map { $0.lowercased() })
        self.redactionToken = redactionToken
    }

    public func mask(headers: [String: String]) -> [String: String] {
        var masked: [String: String] = [:]
        masked.reserveCapacity(headers.count)

        for (key, value) in headers {
            masked[key] = sensitiveHeaders.contains(key.lowercased()) ? redactionToken : value
        }
        return masked
    }

    public func mask(body data: Data?, contentType: String?) -> NetworkLog.Body? {
        guard let data else { return nil }
        let normalizedContentType = contentType?.lowercased() ?? ""
        let shouldMaskJSONKeys = normalizedContentType.contains("application/json")

        let baseData: Data
        if shouldMaskJSONKeys,
           let object = try? JSONSerialization.jsonObject(with: data),
           let maskedObject = mask(json: object),
           JSONSerialization.isValidJSONObject(maskedObject),
           let maskedData = try? JSONSerialization.data(withJSONObject: maskedObject, options: [.prettyPrinted, .sortedKeys]) {
            baseData = maskedData
        } else {
            baseData = data
        }

        guard let text = String(data: baseData, encoding: .utf8) else {
            return .init(data: baseData, contentType: contentType)
        }

        let redactedText = maskSensitiveText(text)
        let redactedData = Data(redactedText.utf8)
        return .init(data: redactedData, contentType: contentType)
    }

    private func mask(json value: Any) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var output: [String: Any] = [:]
            output.reserveCapacity(dictionary.count)
            for (key, nestedValue) in dictionary {
                if sensitiveJSONKeys.contains(key.lowercased()) {
                    output[key] = redactionToken
                } else if let maskedNested = mask(json: nestedValue) {
                    output[key] = maskedNested
                }
            }
            return output
        case let array as [Any]:
            return array.compactMap(mask(json:))
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case _ as NSNull:
            return NSNull()
        default:
            return nil
        }
    }

    private func maskSensitiveText(_ text: String) -> String {
        var redacted = text

        redacted = replacingRegex(
            pattern: "(?im)^(authorization|proxy-authorization|cookie|set-cookie)\\s*:\\s*.*$",
            in: redacted,
            template: "$1: \(redactionToken)"
        )
        redacted = replacingRegex(
            pattern: "(?i)\\bbearer\\s+[a-z0-9\\-._~+/]+=*",
            in: redacted,
            template: "Bearer \(redactionToken)"
        )
        redacted = replacingRegex(
            pattern: "(?is)-----BEGIN(?: [A-Z0-9]+)? PRIVATE KEY-----.*?-----END(?: [A-Z0-9]+)? PRIVATE KEY-----",
            in: redacted,
            template: redactionToken
        )

        return redacted
    }

    private func replacingRegex(pattern: String, in text: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: template)
    }
}
