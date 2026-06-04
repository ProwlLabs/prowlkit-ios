//
//  ProwlEndpointRateAlertsTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation
import Testing
@testable import ProwlCore

// Serialized: tests in this suite mutate the process-wide
// `ProwlEndpointRateAlertCoordinator.shared` singleton (rules + counters),
// so running them in parallel races on shared state.
@Suite("Endpoint rate alerts", .serialized)
struct ProwlEndpointRateAlertsTests {
    @Test("Endpoint rate alert fires exactly when threshold is reached")
    func givenRule_whenHitsReachThreshold_thenThirdRequestAlerts() {
        ProwlEndpointRateAlerts.resetCounters()
        ProwlEndpointRateAlerts.rules = [
            ProwlEndpointRateAlertRule(match: .urlContains("httpbin.org"), threshold: 3)
        ]

        let url = URL(string: "https://httpbin.org/get")!
        let absolute = url.absoluteString

        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: absolute
            ) == false
        )
        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: absolute
            ) == false
        )
        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: absolute
            ) == true
        )
        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: absolute
            ) == false
        )
    }

    @Test("Replacing rules clears counters")
    func whenRulesAreReplaced_thenCountersReset() {
        ProwlEndpointRateAlerts.rules = [
            ProwlEndpointRateAlertRule(match: .urlContains("example.com"), threshold: 1)
        ]
        let url = URL(string: "https://example.com/a")!
        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: url.absoluteString
            ) == true
        )

        ProwlEndpointRateAlerts.rules = [
            ProwlEndpointRateAlertRule(match: .urlContains("example.com"), threshold: 1)
        ]
        #expect(
            ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: "GET",
                url: url,
                absoluteURLString: url.absoluteString
            ) == true
        )
    }
}
