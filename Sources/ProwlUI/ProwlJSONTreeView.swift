//
//  ProwlJSONTreeView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI

enum ProwlJSONColors {
    static let key = Color(red: 0, green: 122 / 255, blue: 1)
    static let string = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let number = Color(red: 1, green: 149 / 255, blue: 0)
    static let literal = Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255)
}

private enum ProwlJSONStyle {
    static let contentFontSize: CGFloat = 12
    static let indent: CGFloat = 12
    static let maxParseDepth = 64
    static let maxNodes = 500
}

enum JSONTreeNode {
    case object(children: [(String, JSONTreeNode)])
    case array(children: [JSONTreeNode])
    case leaf(value: String, color: Color)
}

struct ProwlJSONTreeParseResult {
    let root: JSONTreeNode
    let wasTruncated: Bool
}

private final class NodeBudget {
    private(set) var used = 0
    private(set) var wasTruncated = false
    let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    var isExhausted: Bool {
        used >= limit
    }

    func consume() -> Bool {
        guard used < limit else {
            wasTruncated = true
            return false
        }
        used += 1
        return true
    }

    func markTruncated() {
        wasTruncated = true
    }
}

enum ProwlJSONTreeParser {
    static func parse(_ json: String) -> JSONTreeNode? {
        parseResult(json)?.root
    }

    static func parseResult(_ json: String) -> ProwlJSONTreeParseResult? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        let budget = NodeBudget(limit: ProwlJSONStyle.maxNodes)
        let root = node(for: value, depth: 0, budget: budget)
        return ProwlJSONTreeParseResult(root: root, wasTruncated: budget.wasTruncated)
    }

    private static func node(for value: Any, depth: Int, budget: NodeBudget) -> JSONTreeNode {
        guard budget.consume() else {
            return truncationLeaf(depthTruncated: false)
        }

        guard depth < ProwlJSONStyle.maxParseDepth else {
            budget.markTruncated()
            return truncationLeaf(depthTruncated: true)
        }

        switch value {
        case let dictionary as [String: Any]:
            return objectNode(from: dictionary, depth: depth, budget: budget)
        case let array as [Any]:
            return arrayNode(from: array, depth: depth, budget: budget)
        default:
            return leaf(for: value)
        }
    }

    private static func objectNode(from dictionary: [String: Any], depth: Int, budget: NodeBudget) -> JSONTreeNode {
        var children: [(String, JSONTreeNode)] = []
        let keys = dictionary.keys.sorted()

        for (index, key) in keys.enumerated() {
            if budget.isExhausted {
                budget.markTruncated()
                appendOmittedChildren(count: keys.count - index, into: &children)
                break
            }
            children.append((key, node(for: dictionary[key] ?? NSNull(), depth: depth + 1, budget: budget)))
        }

        return .object(children: children)
    }

    private static func arrayNode(from array: [Any], depth: Int, budget: NodeBudget) -> JSONTreeNode {
        var children: [JSONTreeNode] = []

        for (index, element) in array.enumerated() {
            if budget.isExhausted {
                budget.markTruncated()
                appendOmittedItems(count: array.count - index, into: &children)
                break
            }
            children.append(node(for: element, depth: depth + 1, budget: budget))
        }

        return .array(children: children)
    }

    private static func appendOmittedChildren(count: Int, into children: inout [(String, JSONTreeNode)]) {
        guard count > 0 else { return }
        let label = count == 1 ? "1 more key omitted" : "\(count) more keys omitted"
        children.append(("…", .leaf(value: label, color: ProwlJSONColors.literal)))
    }

    private static func appendOmittedItems(count: Int, into children: inout [JSONTreeNode]) {
        guard count > 0 else { return }
        let label = count == 1 ? "1 more item omitted" : "\(count) more items omitted"
        children.append(.leaf(value: label, color: ProwlJSONColors.literal))
    }

    private static func truncationLeaf(depthTruncated: Bool) -> JSONTreeNode {
        let label = depthTruncated ? "… (max depth reached)" : "… (node limit reached)"
        return .leaf(value: label, color: ProwlJSONColors.literal)
    }

    private static func leaf(for value: Any) -> JSONTreeNode {
        switch value {
        case let number as NSNumber:
            if isBoolean(number) {
                return .leaf(value: number.boolValue ? "true" : "false", color: ProwlJSONColors.literal)
            }
            return .leaf(value: number.stringValue, color: ProwlJSONColors.number)
        case is NSNull:
            return .leaf(value: "null", color: ProwlJSONColors.literal)
        case let string as String:
            return .leaf(value: "\"\(string)\"", color: ProwlJSONColors.string)
        default:
            return .leaf(value: String(describing: value), color: ProwlJSONColors.string)
        }
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

struct ProwlJSONTreeView: View {
    let json: String

    var body: some View {
        if let result = ProwlJSONTreeParser.parseResult(json) {
            VStack(alignment: .leading, spacing: 6) {
                if result.wasTruncated {
                    Text("Large JSON — showing first \(ProwlJSONStyle.maxNodes) nodes. Expand sections to explore.")
                        .font(.system(size: ProwlJSONStyle.contentFontSize))
                        .foregroundColor(.secondary)
                }
                ProwlJSONNodeRows(node: result.root, depth: 0, path: "root")
            }
        } else {
            Text(json)
                .font(.system(size: ProwlJSONStyle.contentFontSize, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

private struct ProwlJSONNodeRows: View {
    let node: JSONTreeNode
    let depth: Int
    let path: String

    var body: some View {
        switch node {
        case let .object(children):
            ForEach(children, id: \.0) { key, child in
                ProwlJSONNodeRow(label: key, node: child, depth: depth, path: "\(path).\(key)")
            }
        case let .array(children):
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                ProwlJSONNodeRow(label: "[\(index)]", node: child, depth: depth, path: "\(path)[\(index)]")
            }
        case let .leaf(value, color):
            Text(value)
                .font(.system(size: ProwlJSONStyle.contentFontSize, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

private struct ProwlJSONNodeRow: View {
    let label: String
    let node: JSONTreeNode
    let depth: Int
    let path: String

    @State private var expanded: Bool

    init(label: String, node: JSONTreeNode, depth: Int, path: String) {
        self.label = label
        self.node = node
        self.depth = depth
        self.path = path
        _expanded = State(initialValue: depth < 1)
    }

    var body: some View {
        switch node {
        case .object, .array:
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                        Text(label)
                            .font(.system(size: ProwlJSONStyle.contentFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(ProwlJSONColors.key)
                    }
                    .padding(.leading, CGFloat(depth) * ProwlJSONStyle.indent)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                if expanded {
                    ProwlJSONNodeRows(node: node, depth: depth + 1, path: path)
                }
            }
            .id(path)
        case let .leaf(value, color):
            HStack(spacing: 0) {
                if label == "…" {
                    Text(value)
                        .font(.system(size: ProwlJSONStyle.contentFontSize, design: .monospaced))
                        .foregroundColor(color)
                } else {
                    Text("\(label): ")
                        .font(.system(size: ProwlJSONStyle.contentFontSize, design: .monospaced))
                        .foregroundColor(ProwlJSONColors.key)
                    Text(value)
                        .font(.system(size: ProwlJSONStyle.contentFontSize, design: .monospaced))
                        .foregroundColor(color)
                }
            }
            .padding(.leading, CGFloat(depth + 1) * ProwlJSONStyle.indent)
            .padding(.vertical, 1)
            .id(path)
        }
    }
}
