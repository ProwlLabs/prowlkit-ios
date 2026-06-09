//
//  ProwlRuleMatcher.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlRuleMatcher {
    static func matches(
        url: String?,
        method: String,
        targetURLPattern: String,
        targetMethod: String,
        isEnabled: Bool
    ) -> Bool {
        guard isEnabled, !targetURLPattern.isEmpty else { return false }
        guard let absoluteURL = url else { return false }
        guard absoluteURL.range(of: targetURLPattern, options: .caseInsensitive) != nil else {
            return false
        }
        if !targetMethod.isEmpty, targetMethod.uppercased() != "ANY" {
            guard method.uppercased() == targetMethod.uppercased() else { return false }
        }
        return true
    }
}
