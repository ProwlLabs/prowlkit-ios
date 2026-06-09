//
//  ProwlHarExporter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlHarExporter {
    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func export(_ logs: [NetworkLog]) -> String {
        let entries = logs.map { entry($0) }
        let root: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": ["name": "Prowl", "version": "1.0.0"],
                "entries": entries,
            ],
        ]
        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func entry(_ log: NetworkLog) -> [String: Any] {
        var dict: [String: Any] = [
            "startedDateTime": isoString(from: log.startedAt),
            "time": log.duration * 1000,
            "request": request(log),
            "response": response(log),
            "cache": [:] as [String: Any],
            "timings": timings(log),
        ]
        if let hostIp = log.hostIp { dict["serverIPAddress"] = hostIp }
        if let url = log.url?.absoluteString { dict["comment"] = url }
        return dict
    }

    private static func request(_ log: NetworkLog) -> [String: Any] {
        var dict: [String: Any] = [
            "method": log.method,
            "url": log.url?.absoluteString ?? "",
            "httpVersion": "HTTP/1.1",
            "headers": headersArray(log.requestHeaders),
            "queryString": [] as [[String: String]],
            "headersSize": -1,
            "bodySize": log.requestBody?.data.count ?? 0,
        ]
        if let body = log.requestBody {
            dict["postData"] = [
                "mimeType": body.contentType ?? "application/octet-stream",
                "text": ProwlBodyDecoder.toText(
                    data: body.data,
                    contentType: body.contentType,
                    contentEncoding: log.requestHeaders["Content-Encoding"]
                ),
            ]
        }
        return dict
    }

    private static func response(_ log: NetworkLog) -> [String: Any] {
        var content: [String: Any] = [:]
        if let body = log.responseBody {
            content = [
                "mimeType": body.contentType ?? "application/octet-stream",
                "size": body.data.count,
                "text": ProwlBodyDecoder.toText(
                    data: body.data,
                    contentType: body.contentType,
                    contentEncoding: log.responseHeaders["Content-Encoding"]
                ),
            ]
        }
        return [
            "status": log.statusCode ?? 0,
            "statusText": log.errorDescription ?? "",
            "httpVersion": "HTTP/1.1",
            "headers": headersArray(log.responseHeaders),
            "content": content,
            "headersSize": -1,
            "bodySize": log.responseBody?.data.count ?? 0,
        ]
    }

    private static func headersArray(_ headers: [String: String]) -> [[String: String]] {
        headers.map { ["name": $0.key, "value": $0.value] }
    }

    private static func timings(_ log: NetworkLog) -> [String: Any] {
        let timing = log.timing
        return [
            "send": Double(timing?.requestBodyMillis ?? 0),
            "wait": Double(timing?.responseHeadersMillis ?? Int(log.duration * 1000)),
            "receive": Double(timing?.responseBodyMillis ?? 0),
            "dns": Double(timing?.dnsMillis ?? -1),
            "connect": Double(timing?.connectMillis ?? -1),
            "ssl": Double(timing?.secureConnectMillis ?? -1),
        ]
    }
}
