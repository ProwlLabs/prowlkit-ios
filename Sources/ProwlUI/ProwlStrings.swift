//
//  ProwlStrings.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlStrings {
    static let totalRequests = String(localized: "Total Requests", bundle: .module)
    static let avgDuration = String(localized: "Avg Duration", bundle: .module)
    static let successRate = String(localized: "Success Rate", bundle: .module)
    static let statusDistribution = String(localized: "Status Distribution", bundle: .module)
    static let methodBreakdown = String(localized: "Method Breakdown", bundle: .module)
    static let persistSessions = String(localized: "Persist sessions", bundle: .module)
    static let persistSessionsHint = String(localized: "Restore captured logs after the app is killed.", bundle: .module)
    static let exportHAR = String(localized: "Export HAR", bundle: .module)
    static let importMocks = String(localized: "Import Mock Rules", bundle: .module)
    static let exportMocks = String(localized: "Export Mock Rules", bundle: .module)
    static let watchEndpoint = String(localized: "Watch Endpoint", bundle: .module)
    static let searchPrompt = String(localized: "Search (method:, status:, host:)", bundle: .module)
    static let timingDNS = String(localized: "DNS", bundle: .module)
    static let timingConnect = String(localized: "Connect", bundle: .module)
    static let timingTLS = String(localized: "TLS", bundle: .module)
    static let timingRequest = String(localized: "Request", bundle: .module)
    static let timingResponse = String(localized: "Response", bundle: .module)
    static let hostIP = String(localized: "Host IP", bundle: .module)
    static let multipartParts = String(localized: "Multipart Parts", bundle: .module)
}
