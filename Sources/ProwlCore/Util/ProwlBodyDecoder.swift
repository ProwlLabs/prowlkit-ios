//
//  ProwlBodyDecoder.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
#if canImport(zlib)
import zlib
#endif

enum ProwlBodyDecoder {
    private static let maxDecompressedBytes = 2 * 1024 * 1024

    static func decodeIfNeeded(_ data: Data, contentEncoding: String?) -> Data {
        guard !data.isEmpty else { return data }
        let encoding = contentEncoding?.lowercased() ?? ""

        // URLSession often strips Content-Encoding after transparent decompression.
        // Only decompress when the bytes still look compressed — never based on the
        // header alone, or plain JSON gets corrupted into garbage like "pQ=".
        if isGzip(data) {
            return decompressGzip(data) ?? data
        }
        if encoding.contains("deflate"), !looksLikeText(data, contentType: nil) {
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
        #if canImport(zlib)
        return inflateZlib(data, windowBits: MAX_WBITS + 32)
        #else
        return nil
        #endif
    }

    private static func decompressDeflate(_ data: Data) -> Data? {
        #if canImport(zlib)
        return inflateZlib(data, windowBits: -MAX_WBITS)
        #else
        return nil
        #endif
    }

    #if canImport(zlib)
    private static func inflateZlib(_ data: Data, windowBits: Int32) -> Data? {
        guard !data.isEmpty else { return nil }

        return data.withUnsafeBytes { rawBuffer -> Data? in
            guard let inputBase = rawBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }

            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: inputBase)
            stream.avail_in = uInt(data.count)

            let initStatus = inflateInit2_(
                &stream,
                windowBits,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard initStatus == Z_OK else { return nil }
            defer { inflateEnd(&stream) }

            var output = Data()
            let chunkSize = 16_384
            var buffer = [UInt8](repeating: 0, count: chunkSize)

            while true {
                let inflateStatus: Int32 = buffer.withUnsafeMutableBytes { outBuffer in
                    guard let outBase = outBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
                        return Z_DATA_ERROR
                    }
                    stream.next_out = outBase
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_SYNC_FLUSH)
                }

                guard inflateStatus == Z_OK || inflateStatus == Z_STREAM_END else { return nil }

                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(buffer, count: produced)
                }

                if inflateStatus == Z_STREAM_END { break }
                if output.count > maxDecompressedBytes { return nil }
            }

            return output.isEmpty ? nil : output
        }
    }
    #endif
}
