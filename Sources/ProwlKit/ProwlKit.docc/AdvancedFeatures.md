# Advanced Features

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Endpoint rate alerts, mocking, request rewriting, session persistence, WebSocket
and gRPC hooks, search syntax, and log export.

## Overview

These features extend what Prowl stores and surfaces in ``ProwlInspectorView``
without changing live `URLSession` responses (except mock rules, which return
synthetic responses for matching requests).

For a single page with every public API and copy-paste snippet, see
<doc:PublicAPIReference>.

## Session persistence

When ``Prowl/isSessionPersistenceEnabled`` is `true`, captured logs are written
to disk and restored on the next ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``
if storage is empty. Toggle from code or from **Settings** in the inspector.

```swift
Prowl.isSessionPersistenceEnabled = true
Prowl.start()
```

## Response mocking

Matching requests return a synthetic HTTP response. Rules persist across launches
and reload automatically at start.

```swift
import ProwlKit
import ProwlCore

Task { @MainActor in
    await Prowl.addMockRule(
        ProwlMockRule(
            targetURLPattern: "/api/users",
            targetMethod: "GET",
            mockStatusCode: 200,
            mockBody: Data(#"{"users":[]}"#.utf8),
            mockHeaders: ["Content-Type": "application/json; charset=utf-8"],
            responseDelayMillis: 300
        )
    )
}
```

Manage rules with ``Prowl/mockRules()``, ``Prowl/addMockRule(_:)``,
``Prowl/saveMockRule(_:)``, ``Prowl/moveMockRuleUp(id:)``,
``Prowl/setMockRuleEnabled(id:enabled:)``, and ``Prowl/removeMockRule(id:)``.

Use a **specific URL pattern** so unrelated endpoints are not mocked.

## Request rewrite rules

Rewrite outgoing requests (URL, headers, body) before they reach the network —
separate from response mocks:

```swift
import ProwlKit
import ProwlCore

Task { @MainActor in
    await Prowl.addRequestRewriteRule(
        ProwlRequestRewriteRule(
            targetURLPattern: "api.staging.example.com",
            replacementURL: "https://api.example.com",
            headerOverrides: ["X-Env": "dev"]
        )
    )
}
```

See ``ProwlRequestRewriteRule`` and ``Prowl/addRequestRewriteRule(_:)``.

## Endpoint rate alerts

Flag endpoints when traffic crosses a threshold. Matching uses HTTP method +
host + path (query string is ignored). The request that hits the threshold sets
``NetworkLog/endpointRateAlertTriggered`` to `true` in the dashboard and detail
view.

```swift
import ProwlKit

Prowl.endpointRateAlertRules = [
    .init(match: .urlContains("https://api.example.com/v1/search"), threshold: 50),
    .init(
        match: .urlRegularExpression(pattern: #"https://telemetry\.[^/]+/collect"#),
        threshold: 20
    )
]
```

Counters reset when you clear logs in the inspector, or manually:

```swift
Prowl.resetEndpointRateAlertCounters()
```

Configure rules through ``Prowl/endpointRateAlertRules`` or directly on
``ProwlEndpointRateAlerts/rules``.

## Response body transform (logging only)

Encrypted, compressed, or custom binary envelopes can be decoded **for display
only** by implementing ``ProwlResponseBodyLoggingTransforming``:

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
        // Return decoded bytes, or nil to keep the original payload.
        nil
    }
}

Prowl.responseBodyLoggingTransformer = MyDecryptor()
Prowl.start()
```

The network response your app receives is unchanged.

## WebSocket logging

Prowl does not auto-intercept WebSockets. Call ``Prowl/logWebSocketEvent(url:event:connectionID:startedAt:)``
from your client, or attach ``ProwlWebSocketMonitor`` to a `URLSessionWebSocketTask`:

```swift
import ProwlKit
import ProwlCore

let connectionID = UUID()
let url = URL(string: "wss://echo.example.com")!

Task { @MainActor in
    await Prowl.logWebSocketEvent(url: url, event: .open, connectionID: connectionID)
    await Prowl.logWebSocketEvent(
        url: url,
        event: .message(text: "hello"),
        connectionID: connectionID
    )
}
```

## gRPC logging

### gRPC Swift 2 (optional)

Add the `ProwlGRPC` product when your app already uses [gRPC Swift 2](https://github.com/grpc/grpc-swift-2) (requires iOS 18+, macOS 15+):

```swift
import GRPCCore
import ProwlGRPC

try await withGRPCClient(
    transport: transport,
    interceptors: [ProwlGrpcSwiftClientInterceptor.registration()]
) { client in
    // invoke generated service methods
}
```

Protobuf messages are encoded with `Encodable` when possible; pass a custom `encodeMessage` closure for `SwiftProtobuf.Message` payloads.

### Manual hook

Log from your own interceptor via ``Prowl/logGrpcCall(fullMethodName:methodType:requestBody:responseBody:grpcStatusCode:errorDescription:startedAt:duration:)``:

```swift
Task { @MainActor in
    await Prowl.logGrpcCall(
        fullMethodName: "/my.package.Service/GetUser",
        methodType: "UNARY",
        requestBody: Data(#"{"id":1}"#.utf8),
        responseBody: Data(#"{"name":"Ada"}"#.utf8),
        grpcStatusCode: 0,
        duration: 0.042
    )
}
```

## Search syntax

The inspector search bar supports structured tokens. Parse the same syntax in
custom tooling with ``ProwlSearchParser``:

```swift
import ProwlCore

let query = ProwlSearchParser.parse("method:GET status:4xx host:api.example.com")
let filtered = logs.filter { ProwlSearchParser.matches($0, query: query) }
```

| Token | Example |
| --- | --- |
| HTTP method | `method:GET` |
| Exact status | `status:404` |
| Status class | `status:4xx` |
| Host substring | `host:api.example.com` |

## Export logs

The inspector toolbar exports the current filtered set:

| Format | Output |
| --- | --- |
| Formatted text | Human-readable entries (``ProwlExportFormat/formattedText``) |
| cURL commands | Executable shell script (``ProwlExportFormat/curlCommands``) |
| HAR 1.2 | Chrome DevTools / Charles archive (``ProwlExportFormat/har``) |

- **iOS** — share sheet (`UIActivityViewController`).
- **macOS** — save panel.

Export programmatically:

```swift
let har = ProwlLogFormatter.export(logs: logs, as: .har)
```

Or use ``ProwlLogFormatter/shareText(log:)`` for a single entry.

## Observe ``NetworkLog`` fields

Each ``NetworkLog`` carries request/response headers and bodies
(``NetworkLog/Body``), timing (``NetworkLog/duration``,
``NetworkLog/startedAt``, ``RequestTiming``), host IP, multipart parts,
mock/rewrite flags, errors (``NetworkLog/errorDescription``), and metadata such
as ``NetworkLog/cachePolicy`` and ``NetworkLog/timeoutInterval``.

Use ``ProwlLogFormatter/bodyText(from:pretty:)`` when building your own
detail views.

## See Also

- <doc:PublicAPIReference>
- ``ProwlMockRule``
- ``ProwlRequestRewriteRule``
- ``ProwlEndpointRateAlertRule``
- ``ProwlResponseBodyLoggingTransforming``
- ``ProwlLogFormatter``
- ``ProwlSearchParser``
- <doc:HTTPClientIntegrations>
