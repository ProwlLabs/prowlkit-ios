//
//  ProwlBodyDecoder.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import Compression

enum ProwlBodyDecoder {
    private static let maxDecompressedBytes = 2 * 1024 * 1024

    static func decodeIfNeeded(_ data: Data, contentEncoding: String?) -> Data {
        guard !data.isEmpty else { return data }
        let encoding = contentEncoding?.lowercased() ?? ""
        if encoding.contains("gzip") || isGzip(data) {
            return decompressGzip(data) ?? data
        }
        if encoding.contains("deflate") {
            return decompressDeflate(data) ?? data
        }
        return data
    }

    static func charset(from contentType: String?) -> String.Encoding {
        guard let contentType else { return .utf8 }
        guard let match = contentType.range(of: #"charset=([^;\s]+)"#, options: .regularExpression) else {
            return .utf8
        }
        let fragment = String(contentType[match])
        let value = fragment
            .replacingOccurrences(of: "charset=", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        if value.isEmpty || value.lowercased() == "utf-8" || value.lowercased() == "utf8" {
            return .utf8
        }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringConvertIANACharSetNameToEncoding(value as CFString)
        ))
    }

    static func toText(data: Data, contentType: String?, contentEncoding: String? = nil) -> String {
        let decoded = decodeIfNeeded(data, contentEncoding: contentEncoding)
        return String(data: decoded, encoding: charset(from: contentType))
            ?? String(decoding: decoded, as: UTF8.self)
    }

    static func isImageContentType(_ contentType: String?) -> Bool {
        let type = contentType?.lowercased() ?? ""
        return type.hasPrefix("image/") && !type.contains("svg")
    }

    static func isBinaryContentType(_ contentType: String?) -> Bool {
        let type = contentType?.lowercased() ?? ""
        if type.isEmpty { return false }
        if isImageContentType(type) { return false }
        if type.contains("json") || type.contains("xml") || type.contains("html")
            || type.contains("text") || type.contains("form") {
            return false
        }
        return type.contains("octet-stream") || type.contains("protobuf")
            || type.contains("grpc") || type.contains("image/")
    }

    static func hexPreview(_ data: Data, maxBytes: Int = 256) -> String {
        let slice = data.prefix(maxBytes)
        let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
        if data.count > maxBytes {
            return "\(hex) … (\(data.count) bytes total)"
        }
        return "\(hex) (\(data.count) bytes)"
    }

    static func looksLikeText(_ data: Data, contentType: String?) -> Bool {
        if isBinaryContentType(contentType) { return false }
        if contentType?.localizedCaseInsensitiveContains("json") == true { return true }
        if contentType?.lowercased().hasPrefix("text/") == true { return true }
        let sample = data.prefix(512)
        if sample.isEmpty { return true }
        var control = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D { continue }
            if byte < 0x20 || byte == 0x7F { control += 1 }
        }
        return Double(control) / Double(sample.count) < 0.1
    }

    private static func isGzip(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x1F && data[data.index(after: data.startIndex)] == 0x8B
    }

    private static func decompressGzip(_ data: Data) -> Data? {
        decompress(data, algorithm: COMPRESSION_ZLIB)
    }

    private static func decompressDeflate(_ data: Data) -> Data? {
        decompress(data, algorithm: COMPRESSION_ZLIB)
    }

    private static func decompress(_ data: Data, algorithm: compression_algorithm) -> Data? {
        data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let dstCapacity = min(max(data.count * 4, 4096), maxDecompressedBytes)
            var dst = Data(count: dstCapacity)
            let decodedSize = dst.withUnsafeMutableBytes { dstBuffer -> Int in
                guard let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    dstPtr, dstCapacity,
                    src, data.count,
                    nil, algorithm
                )
            }
            guard decodedSize > 0, decodedSize <= maxDecompressedBytes else { return nil }
            dst.count = decodedSize
            return dst
        }
    }
}
