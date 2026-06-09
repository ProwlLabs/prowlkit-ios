//
//  ProwlRequestStats.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

struct ProwlRequestStats {
    var total: Int
    var success2xx: Int
    var redirect3xx: Int
    var client4xx: Int
    var server5xx: Int
    var other: Int
    var methodCounts: [String: Int]
    var avgDurationMs: Double

    var successRatePercent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(success2xx) / Double(total) * 100).rounded())
    }
}

enum ProwlRequestStatsCalculator {
    static func compute(from logs: [NetworkLog]) -> ProwlRequestStats {
        var success2xx = 0
        var redirect3xx = 0
        var client4xx = 0
        var server5xx = 0
        var other = 0
        var methodCounts: [String: Int] = [:]
        var durationTotalMs = 0.0

        for log in logs {
            if let code = log.statusCode {
                switch code {
                case 200...299: success2xx += 1
                case 300...399: redirect3xx += 1
                case 400...499: client4xx += 1
                case 500...599: server5xx += 1
                default: other += 1
                }
            } else {
                other += 1
            }
            methodCounts[log.method, default: 0] += 1
            durationTotalMs += log.duration * 1000
        }

        let total = logs.count
        return ProwlRequestStats(
            total: total,
            success2xx: success2xx,
            redirect3xx: redirect3xx,
            client4xx: client4xx,
            server5xx: server5xx,
            other: other,
            methodCounts: methodCounts,
            avgDurationMs: total > 0 ? durationTotalMs / Double(total) : 0
        )
    }
}
