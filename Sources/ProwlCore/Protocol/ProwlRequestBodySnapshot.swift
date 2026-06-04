//
//  ProwlRequestBodySnapshot.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

/// Out-of-band carrier for request body bytes that wouldn't otherwise be
/// reachable from `URLRequest.httpBody`.
///
/// Used for streamed uploads (`httpBodyStream`), where the URL Loading System
/// consumes the stream once and the bytes are gone before `ProwlProtocol` sees
/// them. Attaching a snapshot lets the inspector show what was actually sent.
public enum ProwlRequestBodySnapshot {
    static let key = "com.prowlKit.requestBodySnapshot"

    /// Stores `body` as a snapshot on the request.
    ///
    /// Snapshots are kept in `URLProtocol` properties, so they survive the
    /// trip through `URLSession` and are visible to `ProwlProtocol`.
    public static func attach(_ body: Data, to request: inout URLRequest) {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(body, forKey: key, in: mutableRequest)
        request = mutableRequest as URLRequest
    }

    /// Returns the snapshot previously attached to `request`, if any.
    public static func body(from request: URLRequest) -> Data? {
        URLProtocol.property(forKey: key, in: request) as? Data
    }
}

public extension URLRequest {
    /// Attaches a body snapshot to this request for inspector display.
    ///
    /// Useful when the request body is provided as a stream or generated
    /// lazily by a third-party HTTP client.
    mutating func attachProwlBodySnapshot(_ body: Data) {
        ProwlRequestBodySnapshot.attach(body, to: &self)
    }

    /// Returns a copy of this request with a body snapshot attached.
    func withProwlBodySnapshot(_ body: Data) -> URLRequest {
        var copy = self
        copy.attachProwlBodySnapshot(body)
        return copy
    }

    /// Sets `httpBodyStream` from `body` and attaches the same bytes as a
    /// snapshot, in one step.
    mutating func setProwlHTTPBodyStream(_ body: Data) {
        httpBody = nil
        httpBodyStream = InputStream(data: body)
        attachProwlBodySnapshot(body)
    }

    /// Returns a copy of this request with a stream body and matching snapshot.
    func withProwlHTTPBodyStream(_ body: Data) -> URLRequest {
        var copy = self
        copy.setProwlHTTPBodyStream(body)
        return copy
    }

    /// Encodes `value` to JSON, attaches the bytes as a snapshot, and returns
    /// them for use as `httpBody`.
    @discardableResult
    mutating func attachProwlJSONBodySnapshot<T: Encodable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        let data = try encoder.encode(value)
        attachProwlBodySnapshot(data)
        return data
    }
}
