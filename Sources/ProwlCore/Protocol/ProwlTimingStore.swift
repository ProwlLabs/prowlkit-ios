//
//  ProwlTimingStore.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlTimingStore {
    private struct StoredMetrics {
        var timing: RequestTiming?
        var hostIp: String?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var metricsByTaskID: [Int: StoredMetrics] = [:]

    static func store(_ taskMetrics: URLSessionTaskMetrics, forTaskID taskID: Int) {
        guard let transaction = taskMetrics.transactionMetrics.last else { return }

        let dns = millisBetween(transaction.domainLookupStartDate, transaction.domainLookupEndDate)
        let connect = millisBetween(transaction.connectStartDate, transaction.connectEndDate)
        let tls = millisBetween(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)
        let request = millisBetween(transaction.requestStartDate, transaction.requestEndDate)
        let response = millisBetween(transaction.responseStartDate, transaction.responseEndDate)

        let hostIp = transaction.remoteAddress?
            .split(separator: ":")
            .first
            .map(String.init)

        let timing = RequestTiming(
            dnsMillis: dns,
            connectMillis: connect,
            secureConnectMillis: tls,
            requestHeadersMillis: nil,
            requestBodyMillis: request,
            responseHeadersMillis: nil,
            responseBodyMillis: response
        )

        lock.prowlWithLock {
            metricsByTaskID[taskID] = StoredMetrics(timing: timing, hostIp: hostIp)
        }
    }

    static func take(forTaskID taskID: Int) -> (timing: RequestTiming?, hostIp: String?) {
        lock.prowlWithLock {
            let stored = metricsByTaskID.removeValue(forKey: taskID)
            return (stored?.timing, stored?.hostIp)
        }
    }

    private static func millisBetween(_ start: Date?, _ end: Date?) -> Int? {
        guard let start, let end, end >= start else { return nil }
        return Int((end.timeIntervalSince(start) * 1000).rounded())
    }
}
