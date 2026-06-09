//
//  ProwlNotificationService.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
#if os(iOS)
import UserNotifications
import UIKit

@MainActor
enum ProwlNotificationService {
    private static let notificationID = "com.prowlKit.inspector"
    private static let enabledKey = "prowl_debug_notification"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                requestAuthorization()
            } else {
                dismiss()
            }
        }
    }

    static func install() {
        guard isEnabled else { return }
        requestAuthorization()
    }

    static func uninstall() {
        dismiss()
    }

    static func updateRequestCount(_ count: Int) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Prowl Inspector"
        content.body = "\(count) requests captured"
        content.sound = nil
        content.categoryIdentifier = "prowl_inspector"

        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    private static func dismiss() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }
}
#endif
