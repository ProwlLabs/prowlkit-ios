//
//  ProwlFloatingBubble.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit

enum ProwlUiPreferenceKeys {
    static let floatingBubble = "prowl_floating_bubble"
}

extension Notification.Name {
    static let prowlFloatingBubblePreferenceDidChange = Notification.Name("prowlFloatingBubblePreferenceDidChange")
}

@MainActor
enum ProwlFloatingBubble {
    private static let fabSize: CGFloat = 56
    private static let fabStroke: CGFloat = 2
    private static let iconPadding: CGFloat = 11
    private static let brandPurple = UIColor(red: 0.424, green: 0.361, blue: 0.906, alpha: 1)

    private static var bubbleView: BubbleView?
    private static var observers: [NSObjectProtocol] = []
    private static var isInstalled = false

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: ProwlUiPreferenceKeys.floatingBubble)
    }

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        observers = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { @MainActor in refresh() }
            },
            NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { @MainActor in refresh() }
            },
            NotificationCenter.default.addObserver(
                forName: .prowlFloatingBubblePreferenceDidChange,
                object: nil,
                queue: nil
            ) { _ in
                Task { @MainActor in refresh() }
            },
        ]
        refresh()
    }

    static func uninstall() {
        hide()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        isInstalled = false
    }

    static func refresh() {
        hide()
        guard isInstalled, isEnabled else { return }
        guard ProwlAutoInspector.isInspectorVisible == false else { return }
        guard let window = keyWindow() else { return }
        show(on: window)
    }

    static func hideWhileInspectorVisible() {
        hide()
    }

    private static func show(on window: UIWindow) {
        let bubble = BubbleView(
            size: fabSize,
            strokeWidth: fabStroke,
            iconPadding: iconPadding,
            fillColor: brandPurple
        ) {
            ProwlAutoInspector.toggle()
        }
        bubble.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(bubble)

        let safe = window.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bubble.widthAnchor.constraint(equalToConstant: fabSize),
            bubble.heightAnchor.constraint(equalToConstant: fabSize),
            bubble.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            bubble.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -72),
        ])

        bubbleView = bubble
        bubble.attachDrag(in: window)
    }

    private static func hide() {
        bubbleView?.removeFromSuperview()
        bubbleView = nil
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
        return foregroundWindows.first
    }

    private final class BubbleView: UIView {
        private let onTap: () -> Void
        private var panStart: CGPoint = .zero
        private var centerStart: CGPoint = .zero
        private var didMove = false

        init(
            size: CGFloat,
            strokeWidth: CGFloat,
            iconPadding: CGFloat,
            fillColor: UIColor,
            onTap: @escaping () -> Void
        ) {
            self.onTap = onTap
            super.init(frame: .zero)
            isAccessibilityElement = true
            accessibilityLabel = "Floating debug bubble"
            accessibilityTraits = .button

            backgroundColor = .clear
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.22
            layer.shadowRadius = 8
            layer.shadowOffset = CGSize(width: 0, height: 4)

            let circle = UIView()
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.backgroundColor = fillColor
            circle.layer.cornerRadius = size / 2
            circle.layer.borderWidth = strokeWidth
            circle.layer.borderColor = UIColor.white.cgColor
            circle.isUserInteractionEnabled = false
            addSubview(circle)

            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false
            if let url = Bundle.module.url(forResource: "prowlKitWhite", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                imageView.image = image
            } else {
                imageView.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
                imageView.tintColor = .white
            }
            addSubview(imageView)

            NSLayoutConstraint.activate([
                circle.leadingAnchor.constraint(equalTo: leadingAnchor),
                circle.trailingAnchor.constraint(equalTo: trailingAnchor),
                circle.topAnchor.constraint(equalTo: topAnchor),
                circle.bottomAnchor.constraint(equalTo: bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: iconPadding),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -iconPadding),
                imageView.topAnchor.constraint(equalTo: topAnchor, constant: iconPadding),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -iconPadding),
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func attachDrag(in window: UIWindow) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(pan)
        }

        @objc private func handleTap() {
            guard !didMove else { return }
            onTap()
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let superview else { return }
            switch recognizer.state {
            case .began:
                panStart = recognizer.location(in: superview)
                centerStart = center
                didMove = false
                alpha = 0.92
            case .changed:
                let current = recognizer.location(in: superview)
                let dx = current.x - panStart.x
                let dy = current.y - panStart.y
                if abs(dx) > 8 || abs(dy) > 8 { didMove = true }
                center = CGPoint(x: centerStart.x + dx, y: centerStart.y + dy)
            case .ended, .cancelled:
                alpha = 1
                if !didMove { onTap() }
                didMove = false
            default:
                break
            }
        }
    }
}
#endif
