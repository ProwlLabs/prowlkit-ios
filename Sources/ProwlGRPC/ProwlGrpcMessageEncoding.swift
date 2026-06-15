//
//  ProwlGrpcMessageEncoding.swift
//  ProwlGRPC
//

import Foundation

enum ProwlGrpcMessageEncoding {
    static func defaultEncode(_ message: Any) -> Data? {
        if let data = message as? Data {
            return data
        }
        if let text = message as? String {
            return Data(text.utf8)
        }
        if let encodable = message as? any Encodable {
            return try? JSONEncoder().encode(AnyEncodable(encodable))
        }
        let description = String(describing: message)
        guard !description.isEmpty else { return nil }
        return Data(description.utf8)
    }

    static func combine(_ chunks: [Data], maxBytes: Int) -> Data? {
        guard !chunks.isEmpty else { return nil }

        var combined = Data()
        combined.reserveCapacity(min(maxBytes, chunks.reduce(0) { $0 + $1.count }))

        for chunk in chunks {
            guard !chunk.isEmpty else { continue }
            if !combined.isEmpty {
                combined.append(0x0A)
            }
            let remaining = maxBytes - combined.count
            guard remaining > 0 else { break }
            combined.append(chunk.prefix(remaining))
            if combined.count >= maxBytes {
                break
            }
        }

        return combined.isEmpty ? nil : combined
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
