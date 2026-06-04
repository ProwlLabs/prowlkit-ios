//
//  NetworkLog.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public struct NetworkLog: Identifiable, Sendable, Equatable {
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
