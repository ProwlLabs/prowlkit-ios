//
//  ProwlRequestReplaySafetyTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation
import Testing
@testable import ProwlCore

@Suite("ProwlRequestReplaySafety tests")
struct ProwlRequestReplaySafetyTests {

    @Test("given_stream_json_request_when_checked_then_aggressive_replay_is_allowed")
    func givenStreamJSONRequest_whenChecked_thenAggressiveReplayIsAllowed() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: Data(#"{"ok":true}"#.utf8))

        #expect(ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) == true)
    }

    @Test("given_chunked_transfer_when_checked_then_aggressive_replay_is_blocked")
    func givenChunkedTransfer_whenChecked_thenAggressiveReplayIsBlocked() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        request.httpMethod = "POST"
        request.setValue("chunked", forHTTPHeaderField: "Transfer-Encoding")
        request.httpBodyStream = InputStream(data: Data("payload".utf8))

        #expect(ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) == false)
    }

    @Test("given_multipart_request_when_checked_then_aggressive_replay_is_blocked")
    func givenMultipartRequest_whenChecked_thenAggressiveReplayIsBlocked() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=abc", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: Data("payload".utf8))

        #expect(ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) == false)
    }

    @Test("given_expect_100_continue_when_checked_then_aggressive_replay_is_blocked")
    func givenExpectContinue_whenChecked_thenAggressiveReplayIsBlocked() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        request.httpMethod = "POST"
        request.setValue("100-continue", forHTTPHeaderField: "Expect")
        request.httpBodyStream = InputStream(data: Data("payload".utf8))

        #expect(ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) == false)
    }

    @Test("given_non_stream_request_when_checked_then_aggressive_replay_is_blocked")
    func givenNonStreamRequest_whenChecked_thenAggressiveReplayIsBlocked() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        request.httpMethod = "POST"
        request.httpBody = Data("payload".utf8)

        #expect(ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) == false)
    }
}
