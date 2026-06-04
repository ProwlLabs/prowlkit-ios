//
//  ProwlStorageTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Testing
import Foundation
@testable import ProwlCore

@Test("ProwlStorage enforces limit and keeps newest logs")
func givenStorageLimit_whenAppendingBeyondLimit_thenKeepsMostRecentLogs() async {
    let storage = ProwlStorage(limit: 2)

    await storage.append(makeLog(statusCode: 200, startedAt: Date(timeIntervalSince1970: 1)))
    await storage.append(makeLog(statusCode: 201, startedAt: Date(timeIntervalSince1970: 2)))
    await storage.append(makeLog(statusCode: 202, startedAt: Date(timeIntervalSince1970: 3)))

    let logs = await storage.allLogs()
    #expect(logs.count == 2)
    #expect(logs[0].statusCode == 201)
    #expect(logs[1].statusCode == 202)
}
