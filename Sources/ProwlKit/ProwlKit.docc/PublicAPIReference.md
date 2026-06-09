# Public API Reference

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Complete copy-paste examples for every public ``Prowl`` API and related types.

## Overview

Import **ProwlKit** for the ``Prowl`` facade. Core types such as ``ProwlMockRule``,
``ProwlRequestRewriteRule``, and ``ProwlSearchParser`` are re-exported from
**ProwlCore** — you usually only need `import ProwlKit`.

All ``Prowl`` members are `@MainActor`. Mock and rewrite helpers are `async`.

For a minimal setup, see <doc:GettingStarted>. For HTTP client body capture, see
<doc:HTTPClientIntegrations>.

## Lifecycle

```swift
import ProwlKit

// Start interception (idempotent)
Prowl.start()
Prowl.start(
    ignoredURLs: ["https://firebaselogging.googleapis.com"],
    ignoredURLRegexes: [#"https://telemetry\.[^/]+/collect"#]
)

// Inspector UI
Prowl.show()
Prowl.hide()
Prowl.toggle()

// Stop interception (logs are kept)
Prowl.stop()
```

| API | Description |
| --- | --- |
| ``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` | Registers `URLProtocol` and platform inspector affordances. |
| ``Prowl/stop()`` | Unregisters interception; retains logs in storage. |
| ``Prowl/show()`` | Presents the inspector; starts interception if needed. |
| ``Prowl/hide()`` | Dismisses the inspector. |
| ``Prowl/toggle()`` | Toggles inspector visibility. |

## Storage and configuration

```swift
import ProwlKit
import ProwlCore

let storage = ProwlStorage(limit: 500)
let masker = SensitiveDataMasker(
    sensitiveHeaders: ["authorization", "cookie", "x-api-key"],
    sensitiveJSONKeys: ["password", "token", "accessToken"]
)

Task { @MainActor in
    await Prowl.configure(
        storage: storage,
        masker: masker,
        isLoggingEnabled: true,
        isSensitiveDataMaskingEnabled: false
    )
    Prowl.start()
}

// Read the active store later
Task {
    let store = await Prowl.storage()
    let logs = await store.allLogs()
}
```

| API | Description |
| --- | --- |
| ``Prowl/configure(storage:masker:isLoggingEnabled:isSensitiveDataMaskingEnabled:)`` | Awaits runtime setup before returning. |
| ``Prowl/storage()`` | Returns the active ``ProwlStorage`` actor. |
| ``ProwlStorage`` | FIFO log buffer; default limit `200`. |

See also <doc:Configuration>.

## Ignore rules

```swift
// At startup (see Prowl.start above) or at runtime:
Prowl.ignoreURL("https://res.cloudinary.com/")
Prowl.ignoreURL(regex: #"https://api\.example\.com/v[0-9]+/health"#)

// Replace entire rule sets
Prowl.ignoredURLs = ["https://analytics.example.com"]
Prowl.ignoredURLRegexes = [#"https://.*\.internal/.*"#]
```

| API | Description |
| --- | --- |
| ``Prowl/ignoreURL(_:)`` | Adds a URL substring to the ignore list. |
| ``Prowl/ignoreURL(regex:)`` | Adds a regex pattern to the ignore list. |
| ``Prowl/ignoredURLs`` | Full set of substring rules (get/set). |
| ``Prowl/ignoredURLRegexes`` | Full set of regex rules (get/set). |

## Runtime flags

```swift
Prowl.isLoggingEnabled = false              // pause capture
Prowl.isLoggingEnabled = true               // resume capture

Prowl.isSensitiveDataMaskingEnabled = false // default — show raw values
Prowl.isSensitiveDataMaskingEnabled = true  // redact secrets

Prowl.isSessionPersistenceEnabled = true    // restore logs on next launch
```

| API | Description |
| --- | --- |
| ``Prowl/isLoggingEnabled`` | Pause or resume `URLProtocol` capture. |
| ``Prowl/isSensitiveDataMaskingEnabled`` | Toggle ``SensitiveDataMasker`` at runtime. |
| ``Prowl/isSessionPersistenceEnabled`` | Persist captured logs across app launches. |

## Custom URLSessionDelegate

For certificate pinning, mTLS, or custom server-trust handling:

```swift
final class MySessionDelegate: NSObject, URLSessionDelegate {
    // URLAuthenticationChallenge handling
}

Prowl.customSessionDelegate = MySessionDelegate()
Prowl.start()
```

Set ``Prowl/customSessionDelegate`` **before** ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``.

## Response body transform (logging only)

```swift
import ProwlKit
import ProwlCore

final class MyDecryptor: ProwlResponseBodyLoggingTransforming {
    func responseBodyForLogging(
        data: Data,
        contentType: String?,
        url: URL?,
        statusCode: Int?
    ) -> Data? {
        // Return decoded bytes for display, or nil to keep the original payload.
        nil
    }
}

Prowl.responseBodyLoggingTransformer = MyDecryptor()
Prowl.start()
```

The live `URLSession` response is unchanged — only stored logs and the inspector
are affected.

## Endpoint rate alerts

```swift
Prowl.endpointRateAlertRules = [
    .init(match: .urlContains("https://api.example.com/v1/search"), threshold: 50),
    .init(
        match: .urlRegularExpression(pattern: #"https://telemetry\.[^/]+/collect"#),
        threshold: 20
    )
]

// Counters reset when you clear logs in the inspector, or manually:
Prowl.resetEndpointRateAlertCounters()
```

The request that hits the threshold sets ``NetworkLog/endpointRateAlertTriggered``
to `true`.

## Response mocking

Create rules from the inspector (**Share → Create Mock**) or programmatically.
Rules persist to disk and reload on ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``.

```swift
import ProwlKit
import ProwlCore

Task { @MainActor in
    let rule = ProwlMockRule(
        targetURLPattern: "/api/users",
        targetMethod: "GET",
        mockStatusCode: 200,
        mockBody: Data(#"{"users":[]}"#.utf8),
        mockHeaders: ["Content-Type": "application/json; charset=utf-8"],
        responseDelayMillis: 300
    )

    await Prowl.addMockRule(rule)

    let all = await Prowl.mockRules()
    await Prowl.updateMockRule(rule)
    await Prowl.saveMockRule(rule)
    await Prowl.moveMockRuleUp(id: rule.id)
    await Prowl.moveMockRuleDown(id: rule.id)
    await Prowl.setMockRuleEnabled(id: rule.id, enabled: false)
    await Prowl.removeMockRule(id: rule.id)
    await Prowl.removeAllMockRules()
}
```

Use a **specific URL pattern** (e.g. `/content/api/v4/chapters`) so you do not
accidentally mock unrelated endpoints.

| API | Description |
| --- | --- |
| ``Prowl/mockRules()`` | Returns all rules, oldest first. |
| ``Prowl/addMockRule(_:)`` | Registers a new rule. |
| ``Prowl/updateMockRule(_:)`` | Upserts by id or URL pattern + method. |
| ``Prowl/saveMockRule(_:)`` | Same as update — upsert helper. |
| ``Prowl/moveMockRuleUp(id:)`` | Raises rule priority (evaluated first). |
| ``Prowl/moveMockRuleDown(id:)`` | Lowers rule priority. |
| ``Prowl/setMockRuleEnabled(id:enabled:)`` | Toggle without deleting. |
| ``Prowl/removeMockRule(id:)`` | Removes one rule. |
| ``Prowl/removeAllMockRules()`` | Clears every mock rule. |

## Request rewrite rules

Rewrite outgoing requests before they hit the network (separate from response mocks):

```swift
import ProwlKit
import ProwlCore

Task { @MainActor in
    let rule = ProwlRequestRewriteRule(
        targetURLPattern: "api.staging.example.com",
        targetMethod: "ANY",
        replacementURL: "https://api.example.com",
        headerOverrides: ["X-Env": "dev"],
        headersToRemove: ["X-Old-Header"],
        replacementBody: nil,
        replacementContentType: nil
    )

    await Prowl.addRequestRewriteRule(rule)

    let all = await Prowl.requestRewriteRules()
    await Prowl.updateRequestRewriteRule(rule)
    await Prowl.saveRequestRewriteRule(rule)
    await Prowl.setRequestRewriteRuleEnabled(id: rule.id, enabled: false)
    await Prowl.removeRequestRewriteRule(id: rule.id)
    await Prowl.removeAllRequestRewriteRules()
}
```

| API | Description |
| --- | --- |
| ``Prowl/requestRewriteRules()`` | Returns all rewrite rules. |
| ``Prowl/addRequestRewriteRule(_:)`` | Registers a new rule. |
| ``Prowl/updateRequestRewriteRule(_:)`` | Upserts an existing rule. |
| ``Prowl/saveRequestRewriteRule(_:)`` | Same as update — upsert helper. |
| ``Prowl/setRequestRewriteRuleEnabled(id:enabled:)`` | Toggle without deleting. |
| ``Prowl/removeRequestRewriteRule(id:)`` | Removes one rule. |
| ``Prowl/removeAllRequestRewriteRules()`` | Clears every rewrite rule. |

## WebSocket logging

Prowl does not auto-intercept WebSockets — call the hook from your client or use
``ProwlWebSocketMonitor`` with `URLSessionWebSocketTask`:

```swift
import ProwlKit
import ProwlCore

let connectionID = UUID()
let url = URL(string: "wss://echo.example.com")!

Task { @MainActor in
    await Prowl.logWebSocketEvent(url: url, event: .open, connectionID: connectionID)
    await Prowl.logWebSocketEvent(
        url: url,
        event: .message(text: #"{"hello":"world"}"#),
        connectionID: connectionID
    )
    await Prowl.logWebSocketEvent(
        url: url,
        event: .closed(code: 1000, reason: "done"),
        connectionID: connectionID
    )
}

// URLSession helper — attach before resume()
let task = URLSession.shared.webSocketTask(with: url)
let monitor = ProwlWebSocketMonitor(url: url)
monitor.attach(to: task)
task.resume()
// After receiving messages, forward them:
// monitor.logIncomingMessage(message)
```

| API | Description |
| --- | --- |
| ``Prowl/logWebSocketEvent(url:event:connectionID:startedAt:)`` | Manual lifecycle hook. |
| ``ProwlWebSocketEvent`` | `.open`, `.message`, `.closed`, etc. |
| ``ProwlWebSocketMonitor`` | Delegate helper for `URLSessionWebSocketTask`. |

## gRPC logging

Manual hook — log from your gRPC client interceptor:

```swift
import ProwlKit

Task { @MainActor in
    await Prowl.logGrpcCall(
        fullMethodName: "/my.package.Service/GetUser",
        methodType: "UNARY",
        requestBody: Data(#"{"id":1}"#.utf8),
        responseBody: Data(#"{"name":"Ada"}"#.utf8),
        grpcStatusCode: 0,
        errorDescription: nil,
        startedAt: Date(),
        duration: 0.042
    )
}
```

## Export logs

```swift
import ProwlKit
import ProwlCore

Task {
    let storage = await Prowl.storage()
    let logs = await storage.allLogs()

    let text = ProwlLogFormatter.export(logs: logs, as: .formattedText)
    let curl = ProwlLogFormatter.export(logs: logs, as: .curlCommands)
    let har = ProwlLogFormatter.export(logs: logs, as: .har)
}
```

The inspector toolbar also exports **Formatted Text**, **cURL Commands**, and
**HAR 1.2** via the share sheet (iOS) or save panel (macOS).

| Format | Symbol |
| --- | --- |
| Readable text | ``ProwlExportFormat/formattedText`` |
| Shell replay | ``ProwlExportFormat/curlCommands`` |
| Chrome DevTools / Charles | ``ProwlExportFormat/har`` |

## Search syntax

Type in the inspector search bar, or parse queries yourself:

```swift
import ProwlCore

let query = ProwlSearchParser.parse("method:GET status:4xx host:api.example.com users")
let matches = logs.filter { ProwlSearchParser.matches($0, query: query) }
```

Supported tokens:

| Token | Example |
| --- | --- |
| HTTP method | `method:GET` |
| Exact status | `status:404` |
| Status class | `status:4xx` |
| Host substring | `host:api.example.com` |
| Free text | any remaining words |

## Manual inspector view

```swift
import SwiftUI
import ProwlUI

struct DebugPanelHost: View {
    var body: some View {
        ProwlInspectorView()
    }
}
```

Pass a custom ``ProwlStorage`` when not using the runtime default:

```swift
ProwlInspectorView(storage: myStorage)
```

## HTTP client integrations

| Client | API |
| --- | --- |
| `URLSession` upload | Auto snapshot at start for `uploadTask(with:from:)`; use `setProwlHTTPBodyStream(_:)` / `prowlUploadTask(withStreamedRequest:bodySnapshot:)` for streams |
| Alamofire | ``ProwlAlamofireBodySnapshotInterceptor`` on `Session` |
| Moya | ``ProwlMoyaBodySnapshotPlugin`` in provider plugins |
| Stream bodies | `attachProwlBodySnapshot(_:)` on `URLRequest` |

See <doc:HTTPClientIntegrations> for full snippets.

## See Also

- ``Prowl``
- <doc:GettingStarted>
- <doc:Configuration>
- <doc:AdvancedFeatures>
- <doc:HTTPClientIntegrations>
