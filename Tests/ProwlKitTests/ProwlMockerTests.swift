//
//  ProwlMockerTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Testing
import Foundation
@testable import ProwlCore

@Test("ProwlMocker finds matching enabled rules by URL and method")
func givenEnabledMatchingRule_whenFindingMock_thenReturnsRule() async {
    let mocker = ProwlMocker()
    let rule = ProwlMockRule(
        targetURLPattern: "/anything",
        targetMethod: "POST",
        mockStatusCode: 200,
        mockBody: Data("{\"ok\":true}".utf8),
        isEnabled: true
    )
    await mocker.addRule(rule)

    var request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
    request.httpMethod = "POST"

    let match = await mocker.findMatch(for: request)
    #expect(match?.id == rule.id)
}

@Test("ProwlMocker ignores disabled rules")
func givenDisabledRule_whenFindingMock_thenReturnsNil() async {
    let mocker = ProwlMocker()
    let rule = ProwlMockRule(
        targetURLPattern: "/anything",
        targetMethod: "ANY",
        isEnabled: false
    )
    await mocker.addRule(rule)

    let request = URLRequest(url: URL(string: "https://httpbin.org/anything")!)
    let match = await mocker.findMatch(for: request)
    #expect(match == nil)
}
