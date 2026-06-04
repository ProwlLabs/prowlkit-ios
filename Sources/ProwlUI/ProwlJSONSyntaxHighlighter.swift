//
//  ProwlJSONSyntaxHighlighter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
private typealias ProwlPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias ProwlPlatformColor = NSColor
#endif

enum ProwlJSONSyntaxHighlighter {
    static func highlight(_ text: String, contentType: String?) -> AttributedString {
    #if canImport(UIKit) || canImport(AppKit)
        guard isJSON(contentType: contentType) else {
            return AttributedString(text)
        }

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: defaultLabelColor
            ]
        )

        apply(pattern: #""([^"\\]|\\.)*"\s*:"#, color: .systemBlue, in: attributed)
        apply(pattern: #":\s*"([^"\\]|\\.)*""#, color: .systemGreen, in: attributed)
        apply(pattern: #"\b-?\d+(\.\d+)?\b"#, color: .systemOrange, in: attributed)
        apply(pattern: #"\b(true|false|null)\b"#, color: .systemPurple, in: attributed)

        return AttributedString(attributed)
    #else
        return AttributedString(text)
    #endif
    }

    #if canImport(UIKit) || canImport(AppKit)
    private static var defaultLabelColor: ProwlPlatformColor {
    #if canImport(UIKit)
        return .label
    #else
        return .labelColor
    #endif
    }

    private static func apply(pattern: String, color: ProwlPlatformColor, in attributed: NSMutableAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let range = NSRange(location: 0, length: attributed.string.utf16.count)
        regex.enumerateMatches(in: attributed.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
    #endif

    private static func isJSON(contentType: String?) -> Bool {
        guard let contentType else { return false }
        let lower = contentType.lowercased()
        if lower.contains("json") { return true }
        if lower.contains("+json") { return true }
        return false
    }
}
