//
//  ProwlSessionCodecTests.swift
//  ProwlTests
//

import Foundation
import Testing
@testable import ProwlCore

@Test("ProwlSessionCodec round-trips a network log")
func sessionCodecRoundTrip() throws {
    let log = NetworkLog(
        url: URL(string: "https://api.example.com/users"),
        method: "GET",
        requestHeaders: ["Authorization": "Bearer secret"],
        requestBody: NetworkLog.Body(data: Data(#"{"id":1}"#.utf8), contentType: "application/json"),
        responseHeaders: ["Content-Type": "application/json"],
        responseBody: NetworkLog.Body(data: Data(#"{"ok":true}"#.utf8), contentType: "application/json"),
        statusCode: 200,
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        duration: 0.142,
        hostIp: "127.0.0.1",
        networkProtocol: .http
    )

    let json = ProwlSessionCodec.toJSON([log])
    let restored = ProwlSessionCodec.fromJSON(json)

    #expect(restored.count == 1)
    #expect(restored[0].method == "GET")
    #expect(restored[0].statusCode == 200)
    #expect(restored[0].url?.host == "api.example.com")
    #expect(restored[0].requestHeaders["Authorization"] == "Bearer secret")
}

@Test("ProwlSessionRedactor masks sensitive headers and JSON keys")
func sessionRedactorMasksSecrets() throws {
    let log = NetworkLog(
        url: URL(string: "https://api.example.com/login"),
        method: "POST",
        requestHeaders: ["Authorization": "Bearer abc"],
        requestBody: NetworkLog.Body(data: Data(#"{"password":"hunter2"}"#.utf8), contentType: "application/json"),
        responseHeaders: [:],
        responseBody: NetworkLog.Body(data: Data(#"{"token":"xyz"}"#.utf8), contentType: "application/json"),
        statusCode: 200,
        startedAt: Date(),
        duration: 0.2
    )

    let redacted = ProwlSessionRedactor.redact(log)
    #expect(redacted.requestHeaders["Authorization"] == "[REDACTED]")

    let requestJSON = try #require(String(data: redacted.requestBody!.data, encoding: .utf8))
    #expect(requestJSON.contains("[REDACTED]"))
    #expect(!requestJSON.contains("hunter2"))
}
