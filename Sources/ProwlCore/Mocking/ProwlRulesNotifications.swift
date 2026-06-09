//
//  ProwlRulesNotifications.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

extension Notification.Name {
    public static let prowlMockRulesDidChange = Notification.Name("prowlMockRulesDidChange")
    public static let prowlRewriteRulesDidChange = Notification.Name("prowlRewriteRulesDidChange")
}

package enum ProwlRulesNotifier {
    package static func postMockRulesDidChange() {
        postOnMainThread(.prowlMockRulesDidChange)
    }

    package static func postRewriteRulesDidChange() {
        postOnMainThread(.prowlRewriteRulesDidChange)
    }

    private static func postOnMainThread(_ name: Notification.Name) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }
}
