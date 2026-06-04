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
    private static var popover: NSPopover?
    private static var inspectorWindowController: NSWindowController?

    static func enable() {
        guard statusItem == nil else { return }
        installStatusItem()
    }

    static func disable() {
        closePopover()
        hide()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        actionHandler = nil
        popover = nil
    }

    static func show() {
        let windowController = ensureWindowController()
        guard let window = windowController.window else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        inspectorWindowController?.close()
    }

    static func toggle() {
        if let window = inspectorWindowController?.window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    private static func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let actionHandler = ActionHandler()
        if let button = statusItem.button {
            button.title = "Prowl"
            button.image = menuBarIconImage()
            button.imagePosition = .imageLeading
            button.toolTip = "Open Prowl Inspector Panel"
            button.target = actionHandler
            button.action = #selector(ActionHandler.statusItemClicked(_:))
        }
        self.statusItem = statusItem
        self.actionHandler = actionHandler
    }

    private static func togglePopover(from button: NSStatusBarButton) {
        let popover = ensurePopover()
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private static func closePopover() {
        popover?.performClose(nil)
    }

    private static func ensurePopover() -> NSPopover {
        if let popover {
            return popover
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: ProwlStatusPopoverView(
                icon: menuBarIconImage(),
                onOpenInspector: {
                    closePopover()
                    show()
                },
                onToggleInspector: {
                    closePopover()
                    toggle()
                },
                onHideInspector: {
                    closePopover()
                    hide()
                },
                onClose: {
                    closePopover()
                }
            )
        )

        self.popover = popover
        return popover
    }

    private static func menuBarIconImage() -> NSImage? {
        if let iconURL = Bundle.module.url(forResource: "prowl_icon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            return icon
        }

        return NSImage(
            systemSymbolName: "ladybug.fill",
            accessibilityDescription: "Prowl Inspector"
        )
    }

    private static func ensureWindowController() -> NSWindowController {
        if let inspectorWindowController {
            return inspectorWindowController
        }

        let host = NSHostingController(rootView: ProwlInspectorView())
        let window = NSWindow(contentViewController: host)
        window.title = "Prowl Inspector"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.styleMask.remove(.fullSizeContentView)
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .expanded
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
            ProwlMenuBarInspector.togglePopover(from: button)
        }
    }
}

private struct ProwlStatusPopoverView: View {
    let icon: NSImage?
    let onOpenInspector: () -> Void
    let onToggleInspector: () -> Void
    let onHideInspector: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Text("Prowl Inspector")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text("Network debugger is running. Open inspector from this panel.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Open Inspector", action: onOpenInspector)
                    .buttonStyle(.borderedProminent)
                Button("Toggle", action: onToggleInspector)
                    .buttonStyle(.bordered)
                Button("Hide", action: onHideInspector)
                    .buttonStyle(.bordered)
            }

            Divider()

            Text("Shortcut: Command + Shift + P")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
#endif
