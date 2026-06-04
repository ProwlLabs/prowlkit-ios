//
//  ProwlLogFormatterTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Testing
import Foundation
@testable import ProwlCore

@Test("ProwlLogFormatter formats form-urlencoded body in pretty mode")
func givenFormURLEncodedBody_whenPrettyPrinting_thenReturnsDecodedKeyValueLines() {
    let form = "name=Elmee+Dev&city=Jakarta%20Selatan"
    let body = NetworkLog.Body(
        data: Data(form.utf8),
        contentType: "application/x-www-form-urlencoded"
    )

    let pretty = ProwlLogFormatter.bodyText(from: body, pretty: true)

    #expect(pretty.contains("name = Elmee Dev"))
    #expect(pretty.contains("city = Jakarta Selatan"))
}

@Test("ProwlLogFormatter share text includes important metadata")
func givenLogWithMetadata_whenBuildingShareText_thenIncludesRequiredSectionsAndFooter() {
    let requestBody = NetworkLog.Body(data: Data("{\"a\":1}".utf8), contentType: "application/json")
    let responseBody = NetworkLog.Body(data: Data("{\"ok\":true}".utf8), contentType: "application/json")
    let log = makeLog(
        method: "POST",
        requestBody: requestBody,
        responseBody: responseBody,
        timeoutInterval: 60,
        cachePolicy: "UseProtocolCachePolicy"
    )

    let shared = ProwlLogFormatter.shareText(log: log)

    #expect(shared.contains("*INFO*"))
    #expect(shared.contains("URL:"))
    #expect(shared.contains("https://httpbin.org/anything"))
    #expect(shared.contains("Timeout:"))
    #expect(shared.contains("60.0"))
    #expect(shared.contains("Cache policy:"))
    #expect(shared.contains("UseProtocolCachePolicy"))
    #expect(shared.contains("logged via prowl - [https://github.com/elmeeee/prowl]"))
}

@Test("ProwlLogFormatter share text includes response body section")
func givenLargeResponseBody_whenBuildingShareText_thenIncludesResponseBodySection() {
    let longJSON = "{" + String(repeating: "\"x\":1,", count: 800) + "\"z\":1}"
    let responseBody = NetworkLog.Body(data: Data(longJSON.utf8), contentType: "application/json")
    let log = makeLog(responseBody: responseBody)

    let shared = ProwlLogFormatter.shareText(log: log)

    #expect(shared.contains("--Response Body--"))
    #expect(shared.contains("logged via prowl - [https://github.com/elmeeee/prowl]"))
}
