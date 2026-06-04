//
//  ProwlProtocolTests.swift
//  Prowl
//
//  Created by Elmee on 04/06/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import Testing
@testable import ProwlCore

@Suite("ProwlProtocol canInit", .serialized)
struct ProwlProtocolCanInitTests {
    @Test("canInit returns false when logging is disabled")
    func givenLoggingDisabled_whenCanInit_thenFalse() {
        let previous = ProwlRuntime.isLoggingEnabled
        defer { ProwlRuntime.isLoggingEnabled = previous }

        ProwlRuntime.isLoggingEnabled = false
        let request = URLRequest(url: URL(string: "https://example.com")!)
        #expect(ProwlProtocol.canInit(with: request) == false)
    }

    @Test("canInit returns false for non-HTTP schemes")
    func givenFileScheme_whenCanInit_thenFalse() {
        ProwlRuntime.isLoggingEnabled = true
        let request = URLRequest(url: URL(string: "file:///tmp/foo")!)
        #expect(ProwlProtocol.canInit(with: request) == false)
    }

    @Test("canInit returns false when URL matches an ignore substring")
    func givenIgnoredHost_whenCanInit_thenFalse() {
        ProwlRuntime.isLoggingEnabled = true
        let previous = ProwlRuntime.ignoredURLs
        defer { ProwlRuntime.ignoredURLs = previous }

        ProwlRuntime.ignoredURLs = ["telemetry.example.com"]
        let request = URLRequest(url: URL(string: "https://telemetry.example.com/collect")!)
        #expect(ProwlProtocol.canInit(with: request) == false)
    }

    @Test("canInit returns true for a fresh https request when logging is enabled")
    func givenFreshHTTPSRequest_whenCanInit_thenTrue() {
        ProwlRuntime.isLoggingEnabled = true
        let previous = ProwlRuntime.ignoredURLs
        defer { ProwlRuntime.ignoredURLs = previous }
        ProwlRuntime.ignoredURLs = []

        let request = URLRequest(url: URL(string: "https://api.example.com/v1/users")!)
        #expect(ProwlProtocol.canInit(with: request) == true)
    }
}

@Suite("ProwlProtocol mock delivery", .serialized)
struct ProwlProtocolMockDeliveryTests {
    @Test("ProwlProtocol delivers mock body and status when a rule matches")
    func givenRegisteredMock_whenRequestRuns_thenMockResponseIsReturned() async throws {
        ProwlRuntime.isLoggingEnabled = true
        let previous = ProwlRuntime.ignoredURLs
        defer { ProwlRuntime.ignoredURLs = previous }
        ProwlRuntime.ignoredURLs = []

        let mockBody = Data("{\"mocked\":true}".utf8)
        let rule = ProwlMockRule(
            targetURLPattern: "mocked.example",
            targetMethod: "GET",
            mockStatusCode: 418,
            mockBody: mockBody,
            mockHeaders: ["Content-Type": "application/json"],
            isEnabled: true
        )
        // Replace any prior mock state to avoid cross-test bleed.
        for existing in await ProwlMocker.shared.allRules() {
            await ProwlMocker.shared.removeRule(id: existing.id)
        }
        await ProwlMocker.shared.addRule(rule)
        defer {
            Task { await ProwlMocker.shared.removeRule(id: rule.id) }
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProwlProtocol.self] + (config.protocolClasses ?? [])
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        let url = URL(string: "https://mocked.example/path")!
        let (data, response) = try await session.data(for: URLRequest(url: url))

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 418)
        #expect(data == mockBody)
    }
}

@Suite("ProwlMocker", .serialized)
struct ProwlMockerAdditionalTests {
    @Test("findMatch is case-insensitive on the URL pattern")
    func givenUppercasePattern_whenFindingMock_thenStillMatches() async {
        let mocker = ProwlMocker()
        let rule = ProwlMockRule(targetURLPattern: "USERS", targetMethod: "ANY")
        await mocker.addRule(rule)

        let request = URLRequest(url: URL(string: "https://api.example.com/v1/users")!)
        let match = await mocker.findMatch(for: request)
        #expect(match?.id == rule.id)
    }

    @Test("ANY method matches every HTTP verb")
    func givenAnyMethod_whenFindingMock_thenMatchesPOST() async {
        let mocker = ProwlMocker()
        let rule = ProwlMockRule(targetURLPattern: "/users", targetMethod: "ANY")
        await mocker.addRule(rule)

        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        request.httpMethod = "POST"

        let match = await mocker.findMatch(for: request)
        #expect(match?.id == rule.id)
    }

    @Test("Empty URL pattern never matches")
    func givenEmptyPattern_whenFindingMock_thenReturnsNil() async {
        let mocker = ProwlMocker()
        let rule = ProwlMockRule(targetURLPattern: "")
        await mocker.addRule(rule)

        let request = URLRequest(url: URL(string: "https://api.example.com/anything")!)
        let match = await mocker.findMatch(for: request)
        #expect(match == nil)
    }

    @Test("updateRule replaces the existing rule body")
    func givenExistingRule_whenUpdated_thenLookupReturnsNewFields() async {
        let mocker = ProwlMocker()
        let original = ProwlMockRule(
            targetURLPattern: "/v1/users",
            targetMethod: "GET",
            mockStatusCode: 200,
            mockBody: Data("[]".utf8)
        )
        await mocker.addRule(original)

        var updated = original
        updated.mockStatusCode = 503
        updated.mockBody = Data("err".utf8)
        await mocker.updateRule(updated)

        let request = URLRequest(url: URL(string: "https://api.example.com/v1/users")!)
        let match = await mocker.findMatch(for: request)
        #expect(match?.mockStatusCode == 503)
        #expect(match?.mockBody == Data("err".utf8))
    }
}

@Suite("ProwlStorage", .serialized)
struct ProwlStorageStreamTests {
    @Test("stream() yields the current snapshot, then updates on append and clear")
    func givenObserver_whenLogsAppendAndClear_thenSnapshotsArrive() async {
        let storage = ProwlStorage(limit: 10)
        let seed = NetworkLog(
            url: URL(string: "https://seed.example"),
            method: "GET",
            startedAt: Date(),
            duration: 0.1
        )
        await storage.append(seed)

        var iterator = await storage.stream().makeAsyncIterator()

        let first = await iterator.next()
        #expect(first?.count == 1)
        #expect(first?.first?.url?.host == "seed.example")

        let appended = NetworkLog(
            url: URL(string: "https://second.example"),
            method: "POST",
            startedAt: Date(),
            duration: 0.2
        )
        await storage.append(appended)

        let second = await iterator.next()
        #expect(second?.count == 2)

        await storage.clear()
        let third = await iterator.next()
        #expect(third?.isEmpty == true)
    }
}
