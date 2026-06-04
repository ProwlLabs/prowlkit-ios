//
//  ProwlRequestBodySnapshot.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public enum ProwlRequestBodySnapshot {
    static let key = "com.prowlKit.requestBodySnapshot"

    public static func attach(_ body: Data, to request: inout URLRequest) {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(body, forKey: key, in: mutableRequest)
        request = mutableRequest as URLRequest
    }

    public static func body(from request: URLRequest) -> Data? {
        URLProtocol.property(forKey: key, in: request) as? Data
    }
}

public extension URLRequest {
    mutating func attachProwlBodySnapshot(_ body: Data) {
        ProwlRequestBodySnapshot.attach(body, to: &self)
    }

    func withProwlBodySnapshot(_ body: Data) -> URLRequest {
        var copy = self
        copy.attachProwlBodySnapshot(body)
        return copy
    }

    mutating func setProwlHTTPBodyStream(_ body: Data) {
        httpBody = nil
        httpBodyStream = InputStream(data: body)
        attachProwlBodySnapshot(body)
    }

    func withProwlHTTPBodyStream(_ body: Data) -> URLRequest {
        var copy = self
        copy.setProwlHTTPBodyStream(body)
        return copy
    }

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
