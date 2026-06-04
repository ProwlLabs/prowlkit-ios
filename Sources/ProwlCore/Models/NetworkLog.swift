//
//  NetworkLog.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

/// A single captured network round-trip with request, response, and metadata.
public struct NetworkLog: Identifiable, Sendable, Equatable {
    /// A request or response payload with its declared content type.
    public struct Body: Sendable, Equatable {
        /// Raw bytes (possibly already masked by `SensitiveDataMasker`).
        public let data: Data
        /// The `Content-Type` header value associated with the body, if any.
        public let contentType: String?

        public init(data: Data, contentType: String? = nil) {
            self.data = data
            self.contentType = contentType
        }
    }

    /// Stable identifier for this log row (distinct from `requestID`).
    public let id: UUID
    /// Identifier shared across retries/redirects of the same logical request.
    public let requestID: UUID
    /// The fully-resolved request URL.
    public let url: URL?
    /// Uppercased HTTP method (`GET`, `POST`, …).
    public let method: String
    /// Headers attached to the outbound request.
    public let requestHeaders: [String: String]
    /// Request payload, if any.
    public let requestBody: Body?
    /// Headers returned by the server (or by a mock rule).
    public let responseHeaders: [String: String]
    /// Response payload, possibly transformed by
    /// ``ProwlResponseBodyLoggingTransforming``.
    public let responseBody: Body?
    /// HTTP status code, or `nil` for failed/aborted requests.
    public let statusCode: Int?
    /// When `URLProtocol.startLoading` first fired for this request.
    public let startedAt: Date
    /// Total wall-clock duration from start to completion, in seconds.
    public let duration: TimeInterval
    /// Configured timeout for the request, if known.
    public let timeoutInterval: TimeInterval?
    /// Human-readable cache policy name (`UseProtocolCachePolicy`, etc.).
    public let cachePolicy: String?
    /// Localized error string when the request failed.
    public let errorDescription: String?
    /// `true` when this request caused an
    /// ``ProwlEndpointRateAlertRule`` to hit its threshold.
    public let endpointRateAlertTriggered: Bool

    public init(
        id: UUID = UUID(),
        requestID: UUID = UUID(),
        url: URL?,
        method: String,
        requestHeaders: [String: String] = [:],
        requestBody: Body? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: Body? = nil,
        statusCode: Int? = nil,
        startedAt: Date,
        duration: TimeInterval,
        timeoutInterval: TimeInterval? = nil,
        cachePolicy: String? = nil,
        errorDescription: String? = nil,
        endpointRateAlertTriggered: Bool = false
    ) {
        self.id = id
        self.requestID = requestID
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.statusCode = statusCode
        self.startedAt = startedAt
        self.duration = duration
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
        self.errorDescription = errorDescription
        self.endpointRateAlertTriggered = endpointRateAlertTriggered
    }
}
