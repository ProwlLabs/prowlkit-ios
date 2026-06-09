//
//  RequestTiming.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct RequestTiming: Codable, Sendable, Equatable {
    public var dnsMillis: Int?
    public var connectMillis: Int?
    public var secureConnectMillis: Int?
    public var requestHeadersMillis: Int?
    public var requestBodyMillis: Int?
    public var responseHeadersMillis: Int?
    public var responseBodyMillis: Int?

    public init(
        dnsMillis: Int? = nil,
        connectMillis: Int? = nil,
        secureConnectMillis: Int? = nil,
        requestHeadersMillis: Int? = nil,
        requestBodyMillis: Int? = nil,
        responseHeadersMillis: Int? = nil,
        responseBodyMillis: Int? = nil
    ) {
        self.dnsMillis = dnsMillis
        self.connectMillis = connectMillis
        self.secureConnectMillis = secureConnectMillis
        self.requestHeadersMillis = requestHeadersMillis
        self.requestBodyMillis = requestBodyMillis
        self.responseHeadersMillis = responseHeadersMillis
        self.responseBodyMillis = responseBodyMillis
    }

    public var totalMillis: Int {
        [dnsMillis, connectMillis, secureConnectMillis, requestHeadersMillis,
         requestBodyMillis, responseHeadersMillis, responseBodyMillis]
            .compactMap { $0 }
            .reduce(0, +)
    }
}
