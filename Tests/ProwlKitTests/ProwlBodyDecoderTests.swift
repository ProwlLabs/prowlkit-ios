//
//  ProwlBodyDecoderTests.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import Testing
import zlib
@testable import ProwlCore

@Suite("ProwlBodyDecoder")
struct ProwlBodyDecoderTests {
    @Test("does not re-decompress JSON when Content-Encoding still says gzip")
    func givenDecompressedJSONWithGzipHeader_whenDecode_thenKeepsJSON() {
        let json = Data(#"{"id":1,"title":"hello"}"#.utf8)
        let decoded = ProwlBodyDecoder.decodeIfNeeded(json, contentEncoding: "gzip")
        #expect(decoded == json)
        #expect(String(data: decoded, encoding: .utf8)?.contains("hello") == true)
    }

    @Test("decompresses actual gzip bytes")
    func givenGzipJSON_whenDecode_thenReturnsPlainJSON() throws {
        let json = Data(#"{"ok":true}"#.utf8)
        let gzipped = try gzip(json)
        let decoded = ProwlBodyDecoder.decodeIfNeeded(gzipped, contentEncoding: nil)
        #expect(decoded == json)
    }

    @Test("pretty formatter keeps JSON readable after stale gzip header")
    func givenStoredJSONBody_whenPrettyText_thenShowsJSON() {
        let body = NetworkLog.Body(
            data: Data(#"{"message":"woof","status":"success"}"#.utf8),
            contentType: "application/json; charset=utf-8"
        )
        let text = ProwlLogFormatter.prettyBodyText(from: body)
        #expect(text.contains("woof"))
        #expect(text.contains("message"))
    }
}

private func gzip(_ data: Data) throws -> Data {
    var stream = z_stream()
    var status = deflateInit2_(
        &stream,
        Z_DEFAULT_COMPRESSION,
        Z_DEFLATED,
        MAX_WBITS + 16,
        8,
        Z_DEFAULT_STRATEGY,
        ZLIB_VERSION,
        Int32(MemoryLayout<z_stream>.size)
    )
    guard status == Z_OK else { throw GzipTestError.failed }

    var output = Data()
    let chunkSize = 4096
    var buffer = [UInt8](repeating: 0, count: chunkSize)

    try data.withUnsafeBytes { rawBuffer in
        guard let inputBase = rawBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
            throw GzipTestError.failed
        }
        stream.next_in = UnsafeMutablePointer(mutating: inputBase)
        stream.avail_in = uInt(data.count)

        while true {
            let deflateStatus: Int32 = buffer.withUnsafeMutableBytes { outBuffer in
                guard let outBase = outBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
                    return Z_DATA_ERROR
                }
                stream.next_out = outBase
                stream.avail_out = uInt(chunkSize)
                return deflate(&stream, Z_FINISH)
            }
            guard deflateStatus == Z_OK || deflateStatus == Z_STREAM_END else {
                throw GzipTestError.failed
            }
            let produced = chunkSize - Int(stream.avail_out)
            if produced > 0 {
                output.append(buffer, count: produced)
            }
            if deflateStatus == Z_STREAM_END { break }
        }
    }

    deflateEnd(&stream)
    return output
}

private enum GzipTestError: Error {
    case failed
}
