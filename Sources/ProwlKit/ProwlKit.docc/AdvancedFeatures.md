# Advanced Features

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Endpoint rate alerts, response-body transforms for logging, and log export.

## Overview

These features are optional. They extend what Prowl stores and surfaces in
``ProwlInspectorView`` without changing live `URLSession` responses.

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

## Export logs

The inspector toolbar exports the current filtered set:

| Format | Output |
| --- | --- |
| Formatted text | Human-readable entries (``ProwlExportFormat/formattedText``) |
| cURL commands | Executable shell script (``ProwlExportFormat/curlCommands``) |

- **iOS** — share sheet (`UIActivityViewController`).
- **macOS** — save panel.

Export programmatically with ``ProwlLogFormatter/export(logs:as:)`` or
``ProwlLogFormatter/shareText(log:)`` for a single entry.

## Observe ``NetworkLog`` fields

Each ``NetworkLog`` carries request/response headers and bodies
(``NetworkLog/Body``), timing (``NetworkLog/duration``,
``NetworkLog/startedAt``), errors (``NetworkLog/errorDescription``), and
metadata such as ``NetworkLog/cachePolicy`` and
``NetworkLog/timeoutInterval``.

Use ``ProwlLogFormatter/bodyText(from:pretty:)`` when building your own
detail views.

## See Also

- ``ProwlEndpointRateAlertRule``
- ``ProwlResponseBodyLoggingTransforming``
- ``ProwlLogFormatter``
- <doc:HTTPClientIntegrations>
