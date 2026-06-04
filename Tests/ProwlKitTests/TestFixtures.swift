//
//  TestFixtures.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation
@testable import ProwlCore

func makeLog(
    method: String = "GET",
    requestBody: NetworkLog.Body? = nil,
    responseBody: NetworkLog.Body? = nil,
    statusCode: Int? = 200,
    startedAt: Date = Date(timeIntervalSince1970: 1_776_397_008),
    timeoutInterval: TimeInterval? = nil,
    cachePolicy: String? = nil
) -> NetworkLog {
    NetworkLog(
        url: URL(string: "https://httpbin.org/anything"),
        method: method,
        requestHeaders: [
            "Authorization": "Bearer test",
            "Content-Type": "application/json"
        ],
        requestBody: requestBody,
        responseHeaders: [
            "Content-Type": "application/json; charset=utf-8"
        ],
        responseBody: responseBody,
        statusCode: statusCode,
        startedAt: startedAt,
        duration: 0.48311603,
        timeoutInterval: timeoutInterval,
        cachePolicy: cachePolicy
    )
}
