//
//  SensitiveDataMaskerTests.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Testing
import Foundation
@testable import ProwlCore

@Test("SensitiveDataMasker masks configured headers case-insensitively")
func givenSensitiveHeaderNames_whenMaskingHeaders_thenRedactsConfiguredHeaders() {
    let masker = SensitiveDataMasker(sensitiveHeaders: ["authorization"])
    let headers = [
        "Authorization": "Bearer secret",
        "Content-Type": "application/json"
    ]

    let masked = masker.mask(headers: headers)

    #expect(masked["Authorization"] == "[REDACTED]")
    #expect(masked["Content-Type"] == "application/json")
}

@Test("SensitiveDataMasker masks nested JSON keys")
func givenNestedJSONBody_whenMasking_thenRedactsSensitiveKeysRecursively() throws {
    let masker = SensitiveDataMasker(sensitiveJSONKeys: ["token", "password"])
    let source: [String: Any] = [
        "username": "elmee",
        "token": "top-secret",
        "profile": [
            "password": "123456",
            "city": "Jakarta"
        ]
    ]
    let sourceData = try JSONSerialization.data(withJSONObject: source)

    let maskedBody = masker.mask(body: sourceData, contentType: "application/json")
    #expect(maskedBody != nil)

    let object = try JSONSerialization.jsonObject(with: maskedBody!.data) as? [String: Any]
    let profile = object?["profile"] as? [String: Any]

    #expect(object?["token"] as? String == "[REDACTED]")
    #expect(profile?["password"] as? String == "[REDACTED]")
    #expect(profile?["city"] as? String == "Jakarta")
}
