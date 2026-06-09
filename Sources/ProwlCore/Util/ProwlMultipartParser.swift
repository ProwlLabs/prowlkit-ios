//
//  ProwlMultipartParser.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//


import Foundation

enum ProwlMultipartParser {
    static func parse(body: Data, contentType: String?) -> [MultipartPart] {
        let type = contentType?.lowercased() ?? ""
        guard type.contains("multipart/") else { return [] }
        guard let boundary = extractBoundary(contentType) else { return [] }

        guard let text = String(data: body, encoding: .isoLatin1) else { return [] }
        let delimiter = "--\(boundary)"
        return text.components(separatedBy: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "--" }
            .compactMap { parsePart($0) }
    }

    private static func extractBoundary(_ contentType: String?) -> String? {
        guard let contentType else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: #"boundary=(["']?)([^"';\\s]+)\1"#,
            options: .caseInsensitive
        ) else { return nil }
        let range = NSRange(contentType.startIndex..., in: contentType)
        guard let match = regex.firstMatch(in: contentType, range: range),
              match.numberOfRanges > 2,
              let boundaryRange = Range(match.range(at: 2), in: contentType) else {
            return nil
        }
        return String(contentType[boundaryRange])
    }

    private static func parsePart(_ section: String) -> MultipartPart? {
        let separator = section.contains("\r\n\r\n") ? "\r\n\r\n" : "\n\n"
        guard let splitRange = section.range(of: separator) else { return nil }

        let headerBlock = String(section[..<splitRange.lowerBound])
        var bodyRaw = String(section[splitRange.upperBound...])
        bodyRaw = bodyRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n-"))

        var headers: [String: String] = [:]
        for line in headerBlock.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let idx = trimmed.firstIndex(of: ":") else { continue }
            let name = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let disposition = headers["Content-Disposition"] ?? ""
        let name = captureGroup(#"name="([^"]*)""#, in: disposition)
        let fileName = captureGroup(#"filename="([^"]*)""#, in: disposition)
            ?? captureGroup(#"filename\*=UTF-8''([^;\s]+)"#, in: disposition)
        let partContentType = headers["Content-Type"]
        let bodyBytes = Data(bodyRaw.utf8)
        let isBinary = ProwlBodyDecoder.isBinaryContentType(partContentType)
            || bodyBytes.contains { $0 < 0x09 || (0x0E...0x1F).contains($0) }

        let preview: String
        if isBinary {
            preview = ProwlBodyDecoder.hexPreview(bodyBytes, maxBytes: 64)
        } else if bodyRaw.count > 512 {
            preview = String(bodyRaw.prefix(512)) + "…"
        } else {
            preview = bodyRaw
        }

        return MultipartPart(
            name: name,
            fileName: fileName,
            contentType: partContentType,
            headers: headers,
            sizeBytes: bodyBytes.count,
            textPreview: preview,
            isBinary: isBinary
        )
    }

    private static func captureGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
