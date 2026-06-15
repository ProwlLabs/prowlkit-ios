//
//  ProwlGrpcLogger.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public enum ProwlGrpcLogger {
    public static func logCall(
        fullMethodName: String,
        methodType: String,
        requestBody: Data? = nil,
        responseBody: Data? = nil,
        statusCode: Int? = nil,
        errorDescription: String? = nil,
        startedAt: Date = Date(),
        duration: TimeInterval = 0,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:],
        hostIp: String? = nil
    ) async {
        let url = URL(string: "grpc://\(fullMethodName)")
        let log = NetworkLog(
            url: url,
            method: methodType.uppercased(),
            requestHeaders: requestHeaders,
            requestBody: requestBody.map { NetworkLog.Body(data: $0, contentType: "application/grpc") },
            responseHeaders: responseHeaders,
            responseBody: responseBody.map { NetworkLog.Body(data: $0, contentType: "application/grpc") },
            statusCode: statusCode,
            startedAt: startedAt,
            duration: duration,
            errorDescription: errorDescription,
            hostIp: hostIp,
            networkProtocol: .grpc
        )
        let storage = await ProwlRuntime.shared.currentStorage()
        await storage.append(log)
    }

    public static func mapGrpcStatusToHTTP(_ code: Int) -> Int {
        switch code {
        case 0: return 200
        case 1: return 499
        case 2: return 500
        case 3: return 400
        case 4: return 504
        case 5: return 404
        case 6: return 409
        case 7: return 403
        case 8: return 429
        case 9, 11: return 400
        case 10: return 409
        case 12: return 501
        case 13, 15: return 500
        case 14: return 503
        case 16: return 401
        default: return 500
        }
    }
}
