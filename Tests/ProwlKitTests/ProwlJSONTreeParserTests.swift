//
//  ProwlJSONTreeParserTests.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Testing
@testable import ProwlUI

@Suite("ProwlJSONTreeParser")
struct ProwlJSONTreeParserTests {
    @Test("parses nested object and array")
    func parsesNestedStructure() {
        let json = """
        {"users":[{"id":1,"active":true}],"count":2,"label":null}
        """
        let root = ProwlJSONTreeParser.parse(json)
        guard case let .object(children)? = root else {
            Issue.record("Expected object root")
            return
        }
        #expect(children.map(\.0) == ["count", "label", "users"])
        guard case let .array(userChildren) = children.first(where: { $0.0 == "users" })?.1 else {
            Issue.record("Expected users array")
            return
        }
        #expect(userChildren.count == 1)
    }

    @Test("returns nil for invalid JSON")
    func invalidJSONReturnsNil() {
        #expect(ProwlJSONTreeParser.parse("{not json") == nil)
        #expect(ProwlJSONTreeParser.parse("plain text") == nil)
    }

    @Test("returns nil for empty input")
    func emptyInputReturnsNil() {
        #expect(ProwlJSONTreeParser.parse("") == nil)
        #expect(ProwlJSONTreeParser.parse("   ") == nil)
    }

    @Test("parses primitive root array")
    func primitiveRootArray() {
        let root = ProwlJSONTreeParser.parse("[1,2,3]")
        guard case let .array(children)? = root else {
            Issue.record("Expected array root")
            return
        }
        #expect(children.count == 3)
    }

    @Test("depth limit prevents runaway recursion")
    func depthLimit() {
        var json = ""
        for _ in 0 ..< 80 {
            json += "{\"child\":"
        }
        json += "1"
        for _ in 0 ..< 80 {
            json += "}"
        }
        let root = ProwlJSONTreeParser.parse(json)
        #expect(root != nil)
    }

    @Test("node limit truncates large arrays")
    func nodeLimitTruncatesLargeArrays() {
        let items = (0 ..< 600).map { "\($0)" }.joined(separator: ",")
        let json = "[\(items)]"
        let result = ProwlJSONTreeParser.parseResult(json)
        #expect(result?.wasTruncated == true)
        guard case let .array(children)? = result?.root else {
            Issue.record("Expected array root")
            return
        }
        #expect(children.count < 600)
    }

    @Test("node limit truncates large objects")
    func nodeLimitTruncatesLargeObjects() {
        let entries = (0 ..< 600).map { "\"key\($0)\":\($0)" }.joined(separator: ",")
        let json = "{\(entries)}"
        let result = ProwlJSONTreeParser.parseResult(json)
        #expect(result?.wasTruncated == true)
        guard case let .object(children)? = result?.root else {
            Issue.record("Expected object root")
            return
        }
        #expect(children.count < 600)
        #expect(children.contains(where: { $0.0 == "…" }))
    }
}
