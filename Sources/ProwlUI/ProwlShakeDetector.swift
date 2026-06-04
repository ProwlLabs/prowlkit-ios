//
//  ProwlShakeDetector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
#if os(iOS)
import UIKit
import ObjectiveC.runtime

@MainActor
package enum ProwlShakeMonitor {
    package static let didShakeNotification = Notification.Name("com.prowlKit.didShake")

    private static let debounceInterval: TimeInterval = 1.5
    private static var isInstalled = false
    private static var lastPostedAt: Date?

    package static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        let applicationClass: AnyClass = object_getClass(UIApplication.shared) ?? UIApplication.self
        swizzleMethod(
            on: applicationClass,
            original: #selector(UIApplication.sendEvent(_:)),
            swizzledFrom: UIApplication.self,
            swizzled: #selector(UIApplication.prowl_sendEvent(_:))
        )
        UIApplication.shared.applicationSupportsShakeToEdit = true
    }

    nonisolated package static func postShakeDetected() {
        Task { @MainActor in
            let now = Date()
            if let last = lastPostedAt, now.timeIntervalSince(last) < debounceInterval {
                return
            }
            lastPostedAt = now
            NotificationCenter.default.post(name: didShakeNotification, object: nil)
        }
    }

    private static func swizzleMethod(
        on targetClass: AnyClass,
        original originalSelector: Selector,
        swizzledFrom sourceClass: AnyClass,
        swizzled swizzledSelector: Selector
    ) {
        guard
            let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(sourceClass, swizzledSelector)
        else {
            return
        }

        let didAddSwizzledImplementation = class_addMethod(
            targetClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddSwizzledImplementation {
            class_replaceMethod(
                targetClass,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

struct ProwlShakeDetector: View {
    let onShake: () -> Void

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ProwlShakeMonitor.installIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: ProwlShakeMonitor.didShakeNotification)) { _ in
                onShake()
            }
    }
}

private extension UIApplication {
    @objc dynamic func prowl_sendEvent(_ event: UIEvent) {
        if event.type == .motion, event.subtype == .motionShake {
            ProwlShakeMonitor.postShakeDetected()
            return
        }
        prowl_sendEvent(event)
    }
}

#else
struct ProwlShakeDetector: View {
    let onShake: () -> Void

    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    var body: some View {
        EmptyView()
    }
}
#endif
