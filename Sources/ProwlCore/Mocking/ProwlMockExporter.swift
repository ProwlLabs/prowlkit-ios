//
//  ProwlMockExporter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public enum ProwlMockExporter {
    public static func exportRules(_ rules: [ProwlMockRule]) -> String {
        let objects = rules.map { ruleToDictionary($0) }
        guard JSONSerialization.isValidJSONObject(objects),
              let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    public static func importRules(_ json: String) -> [ProwlMockRule] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix("[") {
            guard let data = trimmed.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return array.compactMap { dictionaryToRule($0) }
        }

        if trimmed.hasPrefix("{") {
            guard let data = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rule = dictionaryToRule(object) else {
                return []
            }
            return [rule]
        }

        return []
    }

    private static func ruleToDictionary(_ rule: ProwlMockRule) -> [String: Any] {
        [
            "id": rule.id.uuidString,
            "targetUrlPattern": rule.targetURLPattern,
            "targetMethod": rule.targetMethod,
            "mockStatusCode": rule.mockStatusCode,
            "mockBodyBase64": rule.mockBody.base64EncodedString(),
            "mockHeaders": rule.mockHeaders,
            "responseDelayMillis": rule.responseDelayMillis,
            "isEnabled": rule.isEnabled,
        ]
    }

    private static func dictionaryToRule(_ object: [String: Any]) -> ProwlMockRule? {
        guard let targetURLPattern = object["targetUrlPattern"] as? String else { return nil }

        let idString = object["id"] as? String ?? ""
        let id = UUID(uuidString: idString) ?? UUID()

        var headers = object["mockHeaders"] as? [String: String] ?? [:]
        if headers.isEmpty {
            headers = ["Content-Type": "application/json"]
        }

        let body: Data
        if let bodyBase64 = object["mockBodyBase64"] as? String, !bodyBase64.isEmpty,
           let decoded = Data(base64Encoded: bodyBase64) {
            body = decoded
        } else if let bodyText = object["mockBody"] as? String {
            body = Data(bodyText.utf8)
        } else {
            body = Data()
        }

        let delay: Int
        if let intDelay = object["responseDelayMillis"] as? Int {
            delay = max(0, intDelay)
        } else if let doubleDelay = object["responseDelayMillis"] as? Double {
            delay = max(0, Int(doubleDelay))
        } else {
            delay = 0
        }

        return ProwlMockRule(
            id: id,
            targetURLPattern: targetURLPattern,
            targetMethod: object["targetMethod"] as? String ?? "ANY",
            mockStatusCode: object["mockStatusCode"] as? Int ?? 200,
            mockBody: body,
            mockHeaders: headers,
            responseDelayMillis: delay,
            isEnabled: object["isEnabled"] as? Bool ?? true
        )
    }
}
