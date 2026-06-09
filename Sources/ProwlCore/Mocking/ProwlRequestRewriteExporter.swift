//
//  ProwlRequestRewriteExporter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlRequestRewriteExporter {
    static func exportRules(_ rules: [ProwlRequestRewriteRule]) -> String {
        let objects = rules.map { ruleToDictionary($0) }
        guard JSONSerialization.isValidJSONObject(objects),
              let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func importRules(_ json: String) -> [ProwlRequestRewriteRule] {
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

    private static func ruleToDictionary(_ rule: ProwlRequestRewriteRule) -> [String: Any] {
        var dict: [String: Any] = [
            "id": rule.id.uuidString,
            "targetUrlPattern": rule.targetURLPattern,
            "targetMethod": rule.targetMethod,
            "replacementUrl": rule.replacementURL,
            "headerOverrides": rule.headerOverrides,
            "headersToRemove": Array(rule.headersToRemove).sorted(),
            "isEnabled": rule.isEnabled,
        ]
        if let body = rule.replacementBody {
            dict["replacementBodyBase64"] = body.base64EncodedString()
        }
        if let contentType = rule.replacementContentType {
            dict["replacementContentType"] = contentType
        }
        return dict
    }

    private static func dictionaryToRule(_ object: [String: Any]) -> ProwlRequestRewriteRule? {
        guard let targetURLPattern = object["targetUrlPattern"] as? String else { return nil }

        let idString = object["id"] as? String ?? ""
        let id = UUID(uuidString: idString) ?? UUID()

        let headerOverrides = object["headerOverrides"] as? [String: String] ?? [:]
        let headersToRemoveArray = object["headersToRemove"] as? [String] ?? []
        let headersToRemove = Set(headersToRemoveArray)

        let replacementBody: Data?
        if let bodyBase64 = object["replacementBodyBase64"] as? String, !bodyBase64.isEmpty {
            replacementBody = Data(base64Encoded: bodyBase64)
        } else if object["replacementBody"] != nil {
            replacementBody = (object["replacementBody"] as? String ?? "").data(using: .utf8)
        } else {
            replacementBody = nil
        }

        let contentType = (object["replacementContentType"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContentType = (contentType?.isEmpty == false) ? contentType : nil

        return ProwlRequestRewriteRule(
            id: id,
            targetURLPattern: targetURLPattern,
            targetMethod: object["targetMethod"] as? String ?? "ANY",
            replacementURL: object["replacementUrl"] as? String ?? "",
            headerOverrides: headerOverrides,
            headersToRemove: headersToRemove,
            replacementBody: replacementBody,
            replacementContentType: normalizedContentType,
            isEnabled: object["isEnabled"] as? Bool ?? true
        )
    }
}
