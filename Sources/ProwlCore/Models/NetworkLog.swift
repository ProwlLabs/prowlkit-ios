//
//  NetworkLog.swift
//  Prowl
//

import Foundation

/// A single captured network round-trip with request, response, and metadata.
public struct NetworkLog: Identifiable, Sendable, Equatable {
    /// A request or response payload with its declared content type.
    public struct Body: Sendable, Equatable {
        public let data: Data
        public let contentType: String?

        public init(data: Data, contentType: String? = nil) {
            self.data = data
            self.contentType = contentType
        }
    }

    public let id: UUID
    public let requestID: UUID
    public let url: URL?
    public let method: String
    public let requestHeaders: [String: String]
    public let requestBody: Body?
    public let responseHeaders: [String: String]
    public let responseBody: Body?
    public let statusCode: Int?
    public let startedAt: Date
    public let duration: TimeInterval
    public let timeoutInterval: TimeInterval?
    public let cachePolicy: String?
    public let errorDescription: String?
    public let endpointRateAlertTriggered: Bool
    public let hostIp: String?
    public let networkProtocol: NetworkProtocol
    public let timing: RequestTiming?
    public let requestMultipartParts: [MultipartPart]
    public let responseMultipartParts: [MultipartPart]
    public let requestRewritten: Bool
    public let responseMocked: Bool

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
        endpointRateAlertTriggered: Bool = false,
        hostIp: String? = nil,
        networkProtocol: NetworkProtocol = .http,
        timing: RequestTiming? = nil,
        requestMultipartParts: [MultipartPart] = [],
        responseMultipartParts: [MultipartPart] = [],
        requestRewritten: Bool = false,
        responseMocked: Bool = false
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
        self.hostIp = hostIp
        self.networkProtocol = networkProtocol
        self.timing = timing
        self.requestMultipartParts = requestMultipartParts
        self.responseMultipartParts = responseMultipartParts
        self.requestRewritten = requestRewritten
        self.responseMocked = responseMocked
    }
}

extension NetworkLog {
    package func endpointKey() -> String {
        let path = url?.path.isEmpty == false ? (url?.path ?? "/") : "/"
        return "\(method.uppercased())::\(path)"
    }
}
