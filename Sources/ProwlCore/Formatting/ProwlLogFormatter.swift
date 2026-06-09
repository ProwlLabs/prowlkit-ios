//
//  ProwlLogFormatter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

/// Output format for bulk log export from the inspector or ``ProwlLogFormatter``.
public enum ProwlExportFormat: String, Sendable {
    /// Human-readable request/response blocks separated by dividers.
    case formattedText
    /// One `curl` command per log, suitable for shell replay.
    case curlCommands
    /// HAR 1.2 JSON for Chrome DevTools and other analyzers.
    case har

    /// Suggested filename when saving or sharing exported content.
    public var fileName: String {
        switch self {
        case .formattedText: return "prowl-logs.txt"
        case .curlCommands: return "prowl-curl.sh"
        case .har: return "prowl.har"
        }
    }
}

/// Converts ``NetworkLog`` entries into shareable text and pretty-printed bodies.
///
/// Used by the inspector export actions and available for custom tooling.
public enum ProwlLogFormatter {

    /// Exports multiple logs in the given ``ProwlExportFormat``.
    public static func export(logs: [NetworkLog], as format: ProwlExportFormat) -> String {
        switch format {
        case .formattedText: return formattedText(logs: logs)
        case .curlCommands: return curlBundle(logs: logs)
        case .har: return ProwlHarExporter.export(logs)
        }
    }

    /// Converts raw body data to the best human-readable string representation.
    /// JSON is always pretty-printed independently of content-type header.
    public static func bodyText(from body: NetworkLog.Body, pretty: Bool) -> String {
        if pretty {
            return prettyBodyText(from: body)
        }
        return String(data: body.data, encoding: .utf8) ?? body.data.base64EncodedString()
    }

    public static func prettyBodyText(from body: NetworkLog.Body) -> String {
        let decoded = ProwlBodyDecoder.decodeIfNeeded(body.data, contentEncoding: nil)

        if ProwlBodyDecoder.isImageContentType(body.contentType) {
            return "Image (\(decoded.count) bytes)"
        }
        if !ProwlBodyDecoder.looksLikeText(decoded, contentType: body.contentType) {
            return ProwlBodyDecoder.hexPreview(decoded)
        }

        if let object = try? JSONSerialization.jsonObject(with: decoded),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: prettyData, encoding: .utf8) {
            return string
        }
        if isFormURLEncoded(body.contentType),
           let formText = String(data: decoded, encoding: .utf8),
           let formatted = prettyFormURLEncodedBody(formText) {
            return formatted
        }
        if let utf8 = String(data: decoded, encoding: .utf8) { return utf8 }
        return decoded.base64EncodedString()
    }

    /// Builds a single-log share payload (same layout as the detail view share action).
    public static func shareText(log: NetworkLog) -> String {
        var lines: [String] = []
        lines.append("*INFO*")
        lines.append("")
        lines.append("URL: \(log.url?.absoluteString ?? "-")")
        lines.append("Method: \(log.method)")
        lines.append("Status: \(log.statusCode.map { String($0) } ?? "N/A")")
        lines.append("Request date: \(String(describing: log.startedAt))")
        lines.append("Response date: \(String(describing: log.startedAt.addingTimeInterval(log.duration)))")
        lines.append("Time interval: \(String(format: "%.8f", log.duration))")
        lines.append("Timeout: \(log.timeoutInterval.map { String($0) } ?? "-")")
        lines.append("Cache policy: \(log.cachePolicy ?? "-")")
        lines.append("")
        lines.append("*REQUEST*")
        lines.append("--Request Headers--")
        for key in log.requestHeaders.keys.sorted() {
            lines.append("\(key): \(log.requestHeaders[key] ?? "")")
        }
        lines.append("")
        lines.append("--Request Payload--")
        lines.append("")
        if let body = log.requestBody, !body.data.isEmpty {
            lines.append(prettyBodyText(from: body))
        } else {
            lines.append("Request body is empty")
        }
        lines.append("")
        lines.append("*RESPONSE*")
        lines.append("")
        lines.append("--Response Headers--")
        lines.append("")
        if log.responseHeaders.isEmpty {
            lines.append("Response headers are empty")
        } else {
            for key in log.responseHeaders.keys.sorted() {
                lines.append("\(key): \(log.responseHeaders[key] ?? "")")
            }
        }
        lines.append("")
        lines.append("--Response Body--")
        lines.append("")
        if let body = log.responseBody, !body.data.isEmpty {
            lines.append(prettyBodyText(from: body))
        } else {
            lines.append("Response body is empty")
        }
        lines.append("")
        lines.append("logged via prowl - [https://github.com/elmeeee/prowl]")
        return lines.joined(separator: "\n")
    }

    private static func isFormURLEncoded(_ contentType: String?) -> Bool {
        guard let contentType else { return false }
        return contentType.lowercased().contains("application/x-www-form-urlencoded")
    }

    private static func prettyFormURLEncodedBody(_ body: String) -> String? {
        let pairs = body.split(separator: "&", omittingEmptySubsequences: false)
        guard !pairs.isEmpty else { return nil }

        let lines = pairs.map { pair -> String in
            let components = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = components.indices.contains(0) ? String(components[0]) : ""
            let rawValue = components.indices.contains(1) ? String(components[1]) : ""
            return "\(decodeFormComponent(rawKey)) = \(decodeFormComponent(rawValue))"
        }
        return lines.joined(separator: "\n")
    }

    private static func decodeFormComponent(_ text: String) -> String {
        let plusAsSpaces = text.replacingOccurrences(of: "+", with: " ")
        return plusAsSpaces.removingPercentEncoding ?? plusAsSpaces
    }

    private static func formattedText(logs: [NetworkLog]) -> String {
        return logs.map { log in
            var c: [String] = []

            c.append("** INFO **")
            c.append(infoText(log: log))

            c.append("** REQUEST **")
            c.append(requestText(log: log, showFullBody: true))

            c.append("** RESPONSE **")
            c.append(responseText(log: log, showFullBody: true))

            return c.joined(separator: "\n")
        }.joined(separator: "\n\n--------------------------------------------------------------\n\n")
    }

    private static func curlBundle(logs: [NetworkLog]) -> String {
        logs.map(curlCommand(for:)).joined(separator: "\n\n")
    }

    private static func curlCommand(for log: NetworkLog) -> String {
        var command = "curl -X \(log.method)"
        for key in log.requestHeaders.keys.sorted() {
            let value = log.requestHeaders[key] ?? ""
            command += " -H '\(escape(value: "\(key): \(value)"))'"
        }
        if let requestBody = log.requestBody,
           let utf8 = String(data: requestBody.data, encoding: .utf8),
           !utf8.isEmpty {
            command += " --data '\(escape(value: utf8))'"
        }
        command += " '\(log.url?.absoluteString ?? "")'"
        return command
    }

    private static func escape(value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }

    private static func infoText(log: NetworkLog) -> String {
        var lines: [String] = []
        lines.append("[URL] ")
        lines.append(log.url?.absoluteString ?? "-")
        lines.append("")
        lines.append("[Method] ")
        lines.append(log.method)
        lines.append("")
        if let statusCode = log.statusCode {
            lines.append("[Status] ")
            lines.append(String(statusCode))
            lines.append("")
        }
        lines.append("[Request date] ")
        lines.append(String(describing: log.startedAt))
        lines.append("")
        if hasResponse(log) {
            lines.append("[Response date] ")
            lines.append(String(describing: log.startedAt.addingTimeInterval(log.duration)))
            lines.append("")
            lines.append("[Time interval] ")
            lines.append(String(Float(log.duration)))
            lines.append("")
        }
        lines.append("[Timeout] ")
        lines.append(log.timeoutInterval.map { String($0) } ?? "-")
        lines.append("")
        lines.append("[Cache policy] ")
        lines.append(log.cachePolicy ?? "-")
        return lines.joined(separator: "\n")
    }

    private static func requestText(log: NetworkLog, showFullBody: Bool) -> String {
        var lines: [String] = []
        lines.append("-- Headers --")
        lines.append("")
        if log.requestHeaders.isEmpty {
            lines.append("Request headers are empty")
            lines.append("")
        } else {
            for key in log.requestHeaders.keys.sorted() {
                lines.append("[\(key)] ")
                lines.append(log.requestHeaders[key] ?? "")
                lines.append("")
            }
        }
        lines.append("-- Body --")
        lines.append("")
        lines.append(bodyTextProwlStyle(body: log.requestBody, emptyText: "Request body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private static func responseText(log: NetworkLog, showFullBody: Bool) -> String {
        guard hasResponse(log) else {
            return "No response"
        }
        var lines: [String] = []
        lines.append("-- Headers --")
        lines.append("")
        if log.responseHeaders.isEmpty {
            lines.append("Response headers are empty")
            lines.append("")
        } else {
            for key in log.responseHeaders.keys.sorted() {
                lines.append("[\(key)] ")
                lines.append(log.responseHeaders[key] ?? "")
                lines.append("")
            }
        }
        lines.append("-- Body --")
        lines.append("")
        lines.append(bodyTextProwlStyle(body: log.responseBody, emptyText: "Response body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private static func bodyTextProwlStyle(body: NetworkLog.Body?, emptyText: String, showFullBody: Bool) -> String {
        guard let body else { return emptyText }
        if body.data.isEmpty { return emptyText }
        if body.data.count > 1024 && !showFullBody {
            return "Too long to show. If you want to see it, please tap the following button"
        }
        return prettyBodyText(from: body)
    }

    private static func hasResponse(_ log: NetworkLog) -> Bool {
        log.statusCode != nil || !log.responseHeaders.isEmpty || log.responseBody != nil
    }
}
