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

@Test("ProwlMocker upserts rules with the same URL pattern and method")
func givenDuplicateMatchKey_whenSavingRule_thenOverwritesExisting() async {
    let mocker = ProwlMocker()
    let first = ProwlMockRule(
        targetURLPattern: "api.example.com",
        targetMethod: "GET",
        mockStatusCode: 404,
        mockBody: Data("not found".utf8)
    )
    await mocker.saveRule(first)

    let second = ProwlMockRule(
        targetURLPattern: "API.EXAMPLE.COM",
        targetMethod: "get",
        mockStatusCode: 200,
        mockBody: Data("ok".utf8)
    )
    await mocker.saveRule(second)

    let rules = await mocker.allRules()
    #expect(rules.count == 1)
    #expect(rules.first?.mockStatusCode == 200)
}

@Test("ProwlMocker moveRuleUp and moveRuleDown reorder priority")
func givenMultipleRules_whenMoving_thenOrderChanges() async {
    let mocker = ProwlMocker()
    let first = ProwlMockRule(targetURLPattern: "first", targetMethod: "ANY", mockStatusCode: 200)
    let second = ProwlMockRule(targetURLPattern: "second", targetMethod: "ANY", mockStatusCode: 201)
    await mocker.saveRule(first)
    await mocker.saveRule(second)

    await mocker.moveRuleUp(id: second.id)
    var rules = await mocker.allRules()
    #expect(rules.first?.targetURLPattern == "second")

    await mocker.moveRuleDown(id: second.id)
    rules = await mocker.allRules()
    #expect(rules.first?.targetURLPattern == "first")
}
