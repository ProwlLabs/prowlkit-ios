//
//  ProwlResponseBodyLoggingTransforming.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

/// Transforms response payloads into a form suitable for display in the inspector.
///
/// Used for responses that arrive encrypted, compressed, or in a custom binary
/// envelope. The live `URLSession` response is unchanged — implementations
/// only affect what Prowl stores and renders. Return `nil` to skip transform
/// and keep the original bytes.
///
/// Implementations must be safe to call from any thread.
public protocol ProwlResponseBodyLoggingTransforming: AnyObject, Sendable {
    /// - Parameters:
    ///   - data: Raw response bytes as received from the network.
    ///   - contentType: The response `Content-Type` header value, if any.
    ///   - url: The request URL the response belongs to.
    ///   - statusCode: HTTP status code of the response.
    /// - Returns: Decoded bytes for the inspector, or `nil` to skip.
    func responseBodyForLogging(
        data: Data,
        contentType: String?,
        url: URL?,
        statusCode: Int?
    ) -> Data?
}
