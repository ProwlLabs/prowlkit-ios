//
//  ProwlRuntimeTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Testing
@testable import ProwlCore

@Suite("ProwlRuntime tests")
struct ProwlRuntimeTests {

    @Test("given_substring_or_regex_ignore_rules_when_matching_url_then_runtime_ignores_it")
    func givenIgnoreRules_whenMatchingURL_thenRuntimeIgnoresIt() {
        let previousIgnored = ProwlRuntime.ignoredURLs
        let previousRegexes = ProwlRuntime.ignoredURLRegexes
        defer {
            ProwlRuntime.ignoredURLs = previousIgnored
            ProwlRuntime.ignoredURLRegexes = previousRegexes
        }

        ProwlRuntime.ignoredURLs = ["mixpanel.com"]
        ProwlRuntime.ignoredURLRegexes = [#"https://api\.example\.com/internal/.*"#]

        #expect(ProwlRuntime.shouldIgnore("https://api.mixpanel.com/track") == true)
        #expect(ProwlRuntime.shouldIgnore("https://api.example.com/internal/health") == true)
        #expect(ProwlRuntime.shouldIgnore("https://api.example.com/public/list") == false)
    }
}
