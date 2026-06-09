# Configuration

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Tune buffer size, sensitive-data masking, and runtime flags before or after
``Prowl/start(ignoredURLs:ignoredURLRegexes:)``.

## Overview

Most apps only need ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``. When you
need a larger log window, custom redaction rules, or guaranteed setup order, use
``Prowl/configure(storage:masker:isLoggingEnabled:isSensitiveDataMaskingEnabled:)``
and the properties on ``Prowl``.

All ``Prowl`` APIs are `@MainActor` — call them from the main thread or inside
a `@MainActor` context.

## Storage and FIFO limit

``ProwlStorage`` is an actor-backed FIFO buffer. The default capacity is
`200` entries; oldest logs drop when the cap is exceeded.

```swift
import ProwlKit
import ProwlCore

let storage = ProwlStorage(limit: 500)

Task { @MainActor in
    await Prowl.configure(storage: storage)
    Prowl.start()
}
```

Read the live store asynchronously:

```swift
let storage = await Prowl.storage()
let snapshot = await storage.allLogs()
```

Subscribe to every mutation (useful for custom dashboards):

```swift
for await logs in await storage.stream() {
    // logs is the full array after each append/clear/limit change
}
```

## Configure before start

``Prowl/configure(storage:masker:isLoggingEnabled:isSensitiveDataMaskingEnabled:)``
awaits the runtime actor so settings apply before it returns. Always `await`
it before ``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` when order matters:

```swift
Task { @MainActor in
    await Prowl.configure(
        storage: ProwlStorage(limit: 500),
        masker: SensitiveDataMasker(
            sensitiveHeaders: ["authorization", "cookie", "x-api-key"],
            sensitiveJSONKeys: ["password", "token", "accessToken"]
        ),
        isSensitiveDataMaskingEnabled: true
    )
    Prowl.start()
}
```

## Sensitive data masking

Default is **off** (raw values in the inspector). Toggle at runtime:

```swift
Prowl.isSensitiveDataMaskingEnabled = false  // default
Prowl.isSensitiveDataMaskingEnabled = true   // redact for demos / screen share
```

``SensitiveDataMasker`` redacts configured header names (case-insensitive) and
JSON keys (including nested objects). It also applies regex passes for inline
`Authorization`, `Bearer …`, `Cookie`, and PEM private-key blocks.

Customize lists via ``SensitiveDataMasker/init(sensitiveHeaders:sensitiveJSONKeys:redactionToken:)``
or use ``SensitiveDataMasker/defaultSensitiveHeaders`` and
``SensitiveDataMasker/defaultSensitiveJSONKeys`` as starting points.

## Custom URLSession delegate

For certificate pinning, mTLS, or custom server-trust handling, set
``Prowl/customSessionDelegate`` **before** ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``:

```swift
final class MySessionDelegate: NSObject, URLSessionDelegate {
    // URLAuthenticationChallenge handling
}

Prowl.customSessionDelegate = MySessionDelegate()
Prowl.start()
```

## Manual inspector host

``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` already presents the inspector
on shake (iOS) or via the menu bar (macOS). To embed the UI yourself:

```swift
import SwiftUI
import ProwlUI

struct DebugPanel: View {
    var body: some View {
        ProwlInspectorView()
    }
}
```

Pass a specific ``ProwlStorage`` instance when you are not using the runtime
default:

```swift
ProwlInspectorView(storage: myStorage)
```

## See Also

- <doc:PublicAPIReference>
- ``Prowl``
- ``ProwlStorage``
- ``SensitiveDataMasker``
- <doc:AdvancedFeatures>
