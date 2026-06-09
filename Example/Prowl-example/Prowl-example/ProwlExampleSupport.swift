import Foundation
import ProwlKit
import ProwlCore

final class ProwlExampleSessionDelegate: NSObject, URLSessionDelegate {}

final class ProwlExampleResponseTransform: ProwlResponseBodyLoggingTransforming {
    func responseBodyForLogging(
        data: Data,
        contentType: String?,
        url: URL?,
        statusCode: Int?
    ) -> Data? {
        nil
    }
}

enum ProwlExampleNetworkLab {
    static let base = URL(string: "https://jsonplaceholder.typicode.com")!

    static func fetchPosts() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("posts"))
        return data
    }

    static func fetchPost(id: Int) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(
            from: base.appendingPathComponent("posts/\(id)")
        )
        return data
    }

    static func createPost() async throws -> Data {
        var request = URLRequest(url: base.appendingPathComponent("posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = Data(#"{"title":"Prowl","body":"stream upload","userId":1}"#.utf8)
        request.setProwlHTTPBodyStream(payload)
        let (data, _) = try await URLSession.shared.upload(for: request, from: payload)
        return data
    }

    static func fetchIgnoredURL() async {
        _ = try? await URLSession.shared.data(from: URL(string: "https://httpbin.org/status/418")!)
    }
}

@MainActor
final class ProwlExampleAPIPlayground: ObservableObject {
    @Published var status = "Ready"
    @Published var exportPreview = ""
    @Published var searchResult = ""

    private var wsConnectionID = UUID()
    private var seededMockID: UUID?
    private var seededRewriteID: UUID?

    func run(_ label: String, _ action: @escaping () async -> Void) {
        Task {
            status = "Running \(label)…"
            await action()
            status = "Done: \(label)"
        }
    }

    // MARK: - Lifecycle

    func showInspector() { Prowl.show(); status = "Prowl.show()" }
    func hideInspector() { Prowl.hide(); status = "Prowl.hide()" }
    func toggleInspector() { Prowl.toggle(); status = "Prowl.toggle()" }
    func restart() {
        Prowl.stop()
        Prowl.start(ignoredURLs: ["https://httpbin.org/status/418"])
        status = "Prowl.stop() → Prowl.start()"
    }

    // MARK: - Flags

    func toggleLogging() {
        Prowl.isLoggingEnabled.toggle()
        status = "isLoggingEnabled = \(Prowl.isLoggingEnabled)"
    }

    func toggleMasking() {
        Prowl.isSensitiveDataMaskingEnabled.toggle()
        status = "isSensitiveDataMaskingEnabled = \(Prowl.isSensitiveDataMaskingEnabled)"
    }

    func togglePersistence() {
        Prowl.isSessionPersistenceEnabled.toggle()
        status = "isSessionPersistenceEnabled = \(Prowl.isSessionPersistenceEnabled)"
    }

    // MARK: - Ignore rules

    func addIgnoreURL() {
        Prowl.ignoreURL("example-telemetry.local")
        status = "ignoreURL added. Count: \(Prowl.ignoredURLs.count)"
    }

    func addIgnoreRegex() {
        Prowl.ignoreURL(regex: #"https://telemetry\.[^/]+/collect"#)
        status = "ignoreURL(regex:) added. Count: \(Prowl.ignoredURLRegexes.count)"
    }

    func replaceIgnoreSets() {
        Prowl.ignoredURLs = ["analytics.example.com"]
        Prowl.ignoredURLRegexes = [#"https://.*\.internal\.example/.*"#]
        status = "ignoredURLs & ignoredURLRegexes replaced"
    }

    // MARK: - Storage

    func readStorage() async {
        let storage = await Prowl.storage()
        let logs = await storage.allLogs()
        status = "storage(): \(logs.count) log(s)"
    }

    // MARK: - Rate alerts

    func resetRateAlerts() {
        Prowl.resetEndpointRateAlertCounters()
        status = "resetEndpointRateAlertCounters()"
    }

    func setRateAlertRules() {
        Prowl.endpointRateAlertRules = [
            .init(match: .urlContains("jsonplaceholder.typicode.com/todos"), threshold: 3)
        ]
        status = "endpointRateAlertRules updated"
    }

    // MARK: - Mock rules

    func demoMockCRUD() async {
        var rules = await Prowl.mockRules()
        if rules.isEmpty {
            let rule = ProwlMockRule(
                targetURLPattern: "jsonplaceholder.typicode.com/posts/777",
                targetMethod: "GET",
                mockStatusCode: 201,
                mockBody: Data(#"{"demo":true}"#.utf8)
            )
            await Prowl.addMockRule(rule)
            seededMockID = rule.id
        } else if let id = rules.first?.id {
            seededMockID = id
            var updated = rules[0]
            updated.mockStatusCode = 418
            await Prowl.updateMockRule(updated)
            await Prowl.saveMockRule(updated)
            await Prowl.moveMockRuleDown(id: id)
            await Prowl.moveMockRuleUp(id: id)
            await Prowl.setMockRuleEnabled(id: id, enabled: false)
            await Prowl.setMockRuleEnabled(id: id, enabled: true)
        }
        rules = await Prowl.mockRules()
        status = "mockRules(): \(rules.count) rule(s)"
    }

    func removeAllMocks() async {
        await Prowl.removeAllMockRules()
        seededMockID = nil
        status = "removeAllMockRules()"
    }

    func removeOneMock() async {
        let fallbackID = await Prowl.mockRules().first?.id
        guard let id = seededMockID ?? fallbackID else {
            status = "No mock rule to remove"
            return
        }
        await Prowl.removeMockRule(id: id)
        status = "removeMockRule(id:)"
    }

    // MARK: - Rewrite rules

    func demoRewriteCRUD() async {
        var rules = await Prowl.requestRewriteRules()
        if rules.isEmpty {
            let rule = ProwlRequestRewriteRule(
                targetURLPattern: "jsonplaceholder.typicode.com/users",
                headerOverrides: ["X-Rewrite": "demo"]
            )
            await Prowl.addRequestRewriteRule(rule)
            seededRewriteID = rule.id
        } else if let id = rules.first?.id {
            seededRewriteID = id
            var updated = rules[0]
            updated.headerOverrides["X-Rewrite"] = "updated"
            await Prowl.updateRequestRewriteRule(updated)
            await Prowl.saveRequestRewriteRule(updated)
            await Prowl.setRequestRewriteRuleEnabled(id: id, enabled: false)
            await Prowl.setRequestRewriteRuleEnabled(id: id, enabled: true)
        }
        rules = await Prowl.requestRewriteRules()
        status = "requestRewriteRules(): \(rules.count) rule(s)"
    }

    func removeAllRewrites() async {
        await Prowl.removeAllRequestRewriteRules()
        seededRewriteID = nil
        status = "removeAllRequestRewriteRules()"
    }

    func removeOneRewrite() async {
        let fallbackID = await Prowl.requestRewriteRules().first?.id
        guard let id = seededRewriteID ?? fallbackID else {
            status = "No rewrite rule to remove"
            return
        }
        await Prowl.removeRequestRewriteRule(id: id)
        status = "removeRequestRewriteRule(id:)"
    }

    // MARK: - WebSocket & gRPC hooks

    func logWebSocketSequence() async {
        let url = URL(string: "wss://echo.websocket.events")!
        await Prowl.logWebSocketEvent(url: url, event: .open, connectionID: wsConnectionID)
        await Prowl.logWebSocketEvent(
            url: url,
            event: .message(text: #"{"from":"Prowl-example"}"#),
            connectionID: wsConnectionID
        )
        await Prowl.logWebSocketEvent(
            url: url,
            event: .closed(code: 1000, reason: "demo"),
            connectionID: wsConnectionID
        )
        status = "logWebSocketEvent × 3"
    }

    func logGrpcCall() async {
        await Prowl.logGrpcCall(
            fullMethodName: "/prowl.example.DemoService/Ping",
            methodType: "UNARY",
            requestBody: Data(#"{"ping":1}"#.utf8),
            responseBody: Data(#"{"pong":1}"#.utf8),
            grpcStatusCode: 0,
            duration: 0.05
        )
        status = "logGrpcCall()"
    }

    // MARK: - Export & search

    func exportLogs() async {
        let storage = await Prowl.storage()
        let logs = await storage.allLogs()
        let text = ProwlLogFormatter.export(logs: logs, as: .formattedText)
        let curl = ProwlLogFormatter.export(logs: logs, as: .curlCommands)
        let har = ProwlLogFormatter.export(logs: logs, as: .har)
        exportPreview = """
        Logs: \(logs.count)
        Text: \(text.prefix(120))…
        cURL lines: \(curl.components(separatedBy: "\n").count)
        HAR bytes: \(har.utf8.count)
        """
        status = "ProwlLogFormatter.export (text, curl, har)"
    }

    func runSearchParser() async {
        let storage = await Prowl.storage()
        let logs = await storage.allLogs()
        let query = ProwlSearchParser.parse("method:GET status:2xx host:jsonplaceholder typicode")
        let matches = logs.filter { ProwlSearchParser.matches($0, query: query) }
        searchResult = "ProwlSearchParser: \(matches.count) match(es) / \(logs.count) logs"
        status = "ProwlSearchParser.parse + matches"
    }
}
