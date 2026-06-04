//  
//  ProwlRequestBodySnapshotTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation
import Testing
@testable import ProwlCore

@Suite("ProwlRequestBodySnapshot tests")
struct ProwlRequestBodySnapshotTests {

    @Test("given_snapshot_when_attached_then_body_can_be_read_back")
    func givenSnapshot_whenAttached_thenBodyCanBeReadBack() {
        var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        let snapshot = Data(#"{"token":"abc123"}"#.utf8)

        request.attachProwlBodySnapshot(snapshot)
        let stored = ProwlRequestBodySnapshot.body(from: request)

        #expect(stored == snapshot)
    }

    @Test("given_with_snapshot_helper_when_used_then_returns_new_request_with_snapshot")
    func givenWithSnapshotHelper_whenUsed_thenReturnsNewRequestWithSnapshot() {
        let request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
        let snapshot = Data("hello".utf8)

        let updated = request.withProwlBodySnapshot(snapshot)

        #expect(ProwlRequestBodySnapshot.body(from: request) == nil)
        #expect(ProwlRequestBodySnapshot.body(from: updated) == snapshot)
    }
}
