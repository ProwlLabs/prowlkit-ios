//
//  ProwlAutoInspector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
#if os(iOS)
import ProwlUI
import SwiftUI
import UIKit

private class ProwlInspectorHostingController: UIHostingController<ProwlInspectorView> {
    override init(rootView: ProwlInspectorView) {
        super.init(rootView: rootView)
        self.modalPresentationStyle = .pageSheet
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
enum ProwlAutoInspector {
    private static var observer: NSObjectProtocol?
    private static var appActiveObserver: NSObjectProtocol?
    private static var lastPresentationDate: Date?
    private static var retryPresentationTask: Task<Void, Never>?
    private static var retryAttempt = 0
    private static let maxRetryAttempts = 6
    private static var isTransitioningInspector = false
    private static var lastToggleAt: Date?
    private static let minimumToggleInterval: TimeInterval = 0.35

    static func enable() {
        guard observer == nil else { return }
        UIApplication.shared.applicationSupportsShakeToEdit = true
        ProwlShakeMonitor.installIfNeeded()
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                resetPendingPresentationRetry()
            }
        }
        observer = NotificationCenter.default.addObserver(
            forName: ProwlShakeMonitor.didShakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                toggle()
            }
        }
    }

    static func disable() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        if let appActiveObserver {
            NotificationCenter.default.removeObserver(appActiveObserver)
            self.appActiveObserver = nil
        }
        resetPendingPresentationRetry()
    }

    static func show() {
        presentIfNeeded()
    }

    static func hide() {
        resetPendingPresentationRetry()
        guard let inspector = presentedInspectorController() else { return }
        isTransitioningInspector = true
        inspector.dismiss(animated: true) {
            Task { @MainActor in
                isTransitioningInspector = false
            }
        }
    }

    static func toggle() {
        guard !isTransitioningInspector else { return }
        let now = Date()
        if let last = lastToggleAt, now.timeIntervalSince(last) < minimumToggleInterval {
            return
        }
        lastToggleAt = now

        if presentedInspectorController() != nil {
            hide()
        } else {
            show()
        }
    }

    private static func presentIfNeeded() {
        guard !isTransitioningInspector else { return }
        guard UIApplication.shared.applicationState == .active else {
            schedulePresentationRetry()
            return
        }
        guard let window = keyWindow() else {
            schedulePresentationRetry()
            return
        }
        guard let root = window.rootViewController else {
            schedulePresentationRetry()
            return
        }
        guard presentedInspectorController() == nil else { return }
        guard let topController = topMostViewController(from: root) else {
            schedulePresentationRetry()
            return
        }

        guard !topController.isBeingPresented,
              !topController.isBeingDismissed,
              topController.presentedViewController == nil else {
            schedulePresentationRetry()
            return
        }

        let inspectorView = ProwlInspectorView()
        let hostController = ProwlInspectorHostingController(rootView: inspectorView)
        isTransitioningInspector = true
        topController.present(hostController, animated: true) {
            Task { @MainActor in
                isTransitioningInspector = false
            }
        }
        resetPendingPresentationRetry()
    }

    private static func schedulePresentationRetry() {
        guard retryAttempt < maxRetryAttempts else { return }
        retryPresentationTask?.cancel()
        retryAttempt += 1

        retryPresentationTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            retryPresentationTask = nil
            presentIfNeeded()
        }
    }

    private static func resetPendingPresentationRetry() {
        retryPresentationTask?.cancel()
        retryPresentationTask = nil
        retryAttempt = 0
    }

    private static func topMostViewController(
        from controller: UIViewController?
    ) -> UIViewController? {
        guard let controller else { return nil }

        // We MUST verify presentedViewController first, because if a UINavigationController
        // has a modal presented over it, navigation.visibleViewController will miss the modal
        // and mistakenly return the underlying UI.
        if let presented = controller.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return topMostViewController(from: navigation.visibleViewController ?? navigation.topViewController)
        }
        if let tab = controller as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }
        return controller
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        
        let foregroundWindows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .filter { $0.rootViewController != nil }
            
        if let activeKeyWindow = foregroundWindows.first(where: \.isKeyWindow) {
            return activeKeyWindow
        }
        if let anyForeground = foregroundWindows.first {
            return anyForeground
        }

        let allWindows = scenes.flatMap(\.windows).filter { $0.rootViewController != nil }
        if let anyKeyWindow = allWindows.first(where: \.isKeyWindow) {
            return anyKeyWindow
        }
        return allWindows.first
    }

    private static func presentedInspectorController() -> UIViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        var cursor: UIViewController? = root
        while let current = cursor {
            if current is ProwlInspectorHostingController {
                return current
            }
            cursor = current.presentedViewController
        }
        return nil
    }
}
#endif
