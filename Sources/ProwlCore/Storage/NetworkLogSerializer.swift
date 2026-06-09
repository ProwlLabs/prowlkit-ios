//
//  NetworkLogSerializer.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum NetworkLogSerializer {
    static func toJSON(_ logs: [NetworkLog]) -> String {
        let objects = logs.map { logToDictionary($0) }
        guard JSONSerialization.isValidJSONObject(objects),
              let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func fromJSON(_ json: String) -> [NetworkLog] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              let data = trimmed.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dictionaryToLog($0) }
    }

    private static func logToDictionary(_ log: NetworkLog) -> [String: Any] {
        var dict: [String: Any] = [
            "id": log.id.uuidString,
            "requestId": log.requestID.uuidString,
            "url": log.url?.absoluteString ?? "",
            "method": log.method,
            "requestHeaders": log.requestHeaders,
            "responseHeaders": log.responseHeaders,
            "startedAtMillis": Int(log.startedAt.timeIntervalSince1970 * 1000),
            "durationMillis": Int(log.duration * 1000),
            "endpointRateAlertTriggered": log.endpointRateAlertTriggered,
            "protocol": log.networkProtocol.rawValue,
            "requestRewritten": log.requestRewritten,
            "responseMocked": log.responseMocked,
        ]
        if let requestBody = log.requestBody { dict["requestBody"] = bodyToDictionary(requestBody) }
        if let responseBody = log.responseBody { dict["responseBody"] = bodyToDictionary(responseBody) }
        if let statusCode = log.statusCode { dict["statusCode"] = statusCode }
        if let timeout = log.timeoutInterval { dict["timeoutMillis"] = Int(timeout * 1000) }
        if let cachePolicy = log.cachePolicy { dict["cachePolicy"] = cachePolicy }
        if let errorDescription = log.errorDescription { dict["errorDescription"] = errorDescription }
        if let hostIp = log.hostIp { dict["hostIp"] = hostIp }
        if let timing = log.timing { dict["timing"] = timingToDictionary(timing) }
        if !log.requestMultipartParts.isEmpty {
            dict["requestMultipartParts"] = log.requestMultipartParts.map { multipartToDictionary($0) }
        }
        if !log.responseMultipartParts.isEmpty {
            dict["responseMultipartParts"] = log.responseMultipartParts.map { multipartToDictionary($0) }
        }
        return dict
    }

    private static func dictionaryToLog(_ object: [String: Any]) -> NetworkLog? {
        guard let method = object["method"] as? String else { return nil }

        let id = UUID(uuidString: object["id"] as? String ?? "") ?? UUID()
        let requestID = UUID(uuidString: object["requestId"] as? String ?? "") ?? UUID()
        let urlString = object["url"] as? String ?? ""
        let url = urlString.isEmpty ? nil : URL(string: urlString)

        let startedMillis = (object["startedAtMillis"] as? NSNumber)?.int64Value
            ?? Int64(object["startedAtMillis"] as? Int ?? 0)
        let durationMillis = (object["durationMillis"] as? NSNumber)?.int64Value
            ?? Int64(object["durationMillis"] as? Int ?? 0)

        let protocolRaw = object["protocol"] as? String ?? NetworkProtocol.http.rawValue
        let networkProtocol = NetworkProtocol(rawValue: protocolRaw) ?? .http

        return NetworkLog(
            id: id,
            requestID: requestID,
            url: url,
            method: method,
            requestHeaders: object["requestHeaders"] as? [String: String] ?? [:],
            requestBody: (object["requestBody"] as? [String: Any]).flatMap(bodyFromDictionary),
            responseHeaders: object["responseHeaders"] as? [String: String] ?? [:],
            responseBody: (object["responseBody"] as? [String: Any]).flatMap(bodyFromDictionary),
            statusCode: object["statusCode"] as? Int,
            startedAt: Date(timeIntervalSince1970: Double(startedMillis) / 1000),
            duration: Double(durationMillis) / 1000,
            timeoutInterval: (object["timeoutMillis"] as? Int).map { Double($0) / 1000 },
            cachePolicy: object["cachePolicy"] as? String,
            errorDescription: object["errorDescription"] as? String,
            endpointRateAlertTriggered: object["endpointRateAlertTriggered"] as? Bool ?? false,
            hostIp: object["hostIp"] as? String,
            networkProtocol: networkProtocol,
            timing: (object["timing"] as? [String: Any]).flatMap(timingFromDictionary),
            requestMultipartParts: (object["requestMultipartParts"] as? [[String: Any]])?.compactMap(multipartFromDictionary) ?? [],
            responseMultipartParts: (object["responseMultipartParts"] as? [[String: Any]])?.compactMap(multipartFromDictionary) ?? [],
            requestRewritten: object["requestRewritten"] as? Bool ?? false,
            responseMocked: object["responseMocked"] as? Bool ?? false
        )
    }

    private static func bodyToDictionary(_ body: NetworkLog.Body) -> [String: Any] {
        var dict: [String: Any] = ["data": body.data.base64EncodedString()]
        if let contentType = body.contentType { dict["contentType"] = contentType }
        return dict
    }

    private static func bodyFromDictionary(_ object: [String: Any]) -> NetworkLog.Body? {
        guard let base64 = object["data"] as? String,
              let data = Data(base64Encoded: base64) else { return nil }
        return NetworkLog.Body(data: data, contentType: object["contentType"] as? String)
    }

    private static func timingToDictionary(_ timing: RequestTiming) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let v = timing.dnsMillis { dict["dnsMillis"] = v }
        if let v = timing.connectMillis { dict["connectMillis"] = v }
        if let v = timing.secureConnectMillis { dict["secureConnectMillis"] = v }
        if let v = timing.requestHeadersMillis { dict["requestHeadersMillis"] = v }
        if let v = timing.requestBodyMillis { dict["requestBodyMillis"] = v }
        if let v = timing.responseHeadersMillis { dict["responseHeadersMillis"] = v }
        if let v = timing.responseBodyMillis { dict["responseBodyMillis"] = v }
        return dict
    }

    private static func timingFromDictionary(_ object: [String: Any]) -> RequestTiming {
        RequestTiming(
            dnsMillis: object["dnsMillis"] as? Int,
            connectMillis: object["connectMillis"] as? Int,
            secureConnectMillis: object["secureConnectMillis"] as? Int,
            requestHeadersMillis: object["requestHeadersMillis"] as? Int,
            requestBodyMillis: object["requestBodyMillis"] as? Int,
            responseHeadersMillis: object["responseHeadersMillis"] as? Int,
            responseBodyMillis: object["responseBodyMillis"] as? Int
        )
    }

    private static func multipartToDictionary(_ part: MultipartPart) -> [String: Any] {
        var dict: [String: Any] = [
            "headers": part.headers,
            "sizeBytes": part.sizeBytes,
            "isBinary": part.isBinary,
        ]
        if let name = part.name { dict["name"] = name }
        if let fileName = part.fileName { dict["fileName"] = fileName }
        if let contentType = part.contentType { dict["contentType"] = contentType }
        if let textPreview = part.textPreview { dict["textPreview"] = textPreview }
        return dict
    }

    private static func multipartFromDictionary(_ object: [String: Any]) -> MultipartPart? {
        MultipartPart(
            name: object["name"] as? String,
            fileName: object["fileName"] as? String,
            contentType: object["contentType"] as? String,
            headers: object["headers"] as? [String: String] ?? [:],
            sizeBytes: object["sizeBytes"] as? Int ?? 0,
            textPreview: object["textPreview"] as? String,
            isBinary: object["isBinary"] as? Bool ?? false
        )
    }
}
