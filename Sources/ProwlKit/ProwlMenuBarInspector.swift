//
//  ProwlMenuBarInspector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
import ProwlUI
import SwiftUI

@MainActor
enum ProwlMenuBarInspector {
    private static var statusItem: NSStatusItem?
    private static var actionHandler: ActionHandler?
    private static var inspectorWindowController: NSWindowController?
    private static var globalKeyboardMonitor: Any?
    private static var localKeyboardMonitor: Any?

    static func enable() {
        guard statusItem == nil else { return }
        installStatusItem()
        installKeyboardShortcut()
    }

    static func disable() {
        removeKeyboardShortcut()
        hide()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        actionHandler = nil
        inspectorWindowController = nil
    }

    static func show() {
        let windowController = ensureWindowController()
        guard let window = windowController.window else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        inspectorWindowController?.window?.orderOut(nil)
    }

    static func toggle() {
        if let window = inspectorWindowController?.window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    private static let menuBarIconHeight: CGFloat = 18

    private static func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let actionHandler = ActionHandler()
        if let button = statusItem.button, let icon = menuBarIconImage() {
            button.title = ""
            button.image = icon
            button.imagePosition = .imageOnly
            button.toolTip = "Prowl Inspector (⌘⇧P)"
            button.target = actionHandler
            button.action = #selector(ActionHandler.statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusItem.length = icon.size.width + 8
        }
        self.statusItem = statusItem
        self.actionHandler = actionHandler
    }

    private static func installKeyboardShortcut() {
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = handleKeyboardShortcut(event)
        }
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyboardShortcut(event) ? nil : event
        }
    }

    private static func removeKeyboardShortcut() {
        if let globalKeyboardMonitor {
            NSEvent.removeMonitor(globalKeyboardMonitor)
            self.globalKeyboardMonitor = nil
        }
        if let localKeyboardMonitor {
            NSEvent.removeMonitor(localKeyboardMonitor)
            self.localKeyboardMonitor = nil
        }
    }

    @discardableResult
    private static func handleKeyboardShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.modifierFlags.contains(.shift),
              event.charactersIgnoringModifiers?.lowercased() == "p" else {
            return false
        }
        toggle()
        return true
    }

    private static func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let isVisible = inspectorWindowController?.window?.isVisible == true

        let toggleItem = NSMenuItem(
            title: isVisible ? "Hide Inspector" : "Show Inspector",
            action: #selector(ActionHandler.toggleInspector(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = actionHandler
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(
            title: "Shortcut: ⌘⇧P",
            action: nil,
            keyEquivalent: ""
        )
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private static func menuBarIconImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "prowlKitWhite", withExtension: "png"),
              let icon = NSImage(contentsOf: url) else {
            return nil
        }

        let aspect = icon.size.width / max(icon.size.height, 1)
        icon.size = NSSize(width: menuBarIconHeight * aspect, height: menuBarIconHeight)
        icon.isTemplate = false
        return icon
    }

    private static func ensureWindowController() -> NSWindowController {
        if let inspectorWindowController {
            return inspectorWindowController
        }

        let host = NSHostingController(rootView: ProwlInspectorView())
        let window = NSWindow(contentViewController: host)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 980, height: 680))
        window.minSize = NSSize(width: 860, height: 560)
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        inspectorWindowController = controller
        return controller
    }

    @MainActor
    private final class ActionHandler: NSObject {
        @objc func statusItemClicked(_ sender: Any?) {
            guard let button = ProwlMenuBarInspector.statusItem?.button else { return }

            if NSApp.currentEvent?.type == .rightMouseUp {
                ProwlMenuBarInspector.showContextMenu(from: button)
            } else {
                ProwlMenuBarInspector.toggle()
            }
        }

        @objc func toggleInspector(_ sender: Any?) {
            ProwlMenuBarInspector.toggle()
        }
    }
}
#endif
