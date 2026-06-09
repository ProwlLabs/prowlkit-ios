//
//  ProwlRequestRewriterTests.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import Testing
@testable import ProwlCore

@Test("ProwlRequestRewriter finds matching enabled rules")
func givenEnabledRewriteRule_whenFindingMatch_thenReturnsRule() async {
    let rewriter = ProwlRequestRewriter()
    let rule = ProwlRequestRewriteRule(
        targetURLPattern: "/users",
        targetMethod: "POST",
        replacementURL: "https://staging.example.com/v2/users",
        isEnabled: true
    )
    await rewriter.addRule(rule)

    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"

    let match = await rewriter.findMatch(for: request)
    #expect(match?.id == rule.id)
}

@Test("ProwlRequestRewriter apply replaces URL and headers")
func givenRewriteRule_whenApplying_thenRequestIsModified() async {
    let rewriter = ProwlRequestRewriter()
    let rule = ProwlRequestRewriteRule(
        targetURLPattern: "api.example.com",
        targetMethod: "ANY",
        replacementURL: "https://staging.example.com/v2/items",
        headerOverrides: ["Authorization": "Bearer test"],
        headersToRemove: ["Cookie"],
        isEnabled: true
    )

    var request = URLRequest(url: URL(string: "https://api.example.com/items")!)
    request.httpMethod = "GET"
    request.setValue("secret", forHTTPHeaderField: "Cookie")
    request.setValue("old", forHTTPHeaderField: "Authorization")

    let rewritten = await rewriter.apply(to: request, rule: rule)
    #expect(rewritten.url?.absoluteString == "https://staging.example.com/v2/items")
    #expect(rewritten.value(forHTTPHeaderField: "Authorization") == "Bearer test")
    #expect(rewritten.value(forHTTPHeaderField: "Cookie") == nil)
}
