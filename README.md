# ProwlKit

<p align="center">
  <img src="Sources/ProwlKit/Resources/prowlKit.png" alt="Prowl Icon" width="220" />
</p>

<p align="center">
  <a href="https://github.com/ProwlLabs/prowlkit-ios/releases/latest"><img alt="Version" src="https://img.shields.io/github/v/tag/ProwlLabs/prowlkit-ios?label=version&sort=semver"></a>
  <a href="https://github.com/ProwlLabs/prowlkit-ios/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/ProwlLabs/prowlkit-ios/ci.yml?branch=main&label=ci"></a>
  <img alt="iOS" src="https://img.shields.io/badge/iOS-15%2B-0A84FF">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.2-F05138">
</p>

Prowl is a lightweight, high-performance network debugging library for the Apple ecosystem (`iOS`, `macOS`, `watchOS`, `tvOS`, `visionOS`) built with native `Foundation` + `SwiftUI` and distributed via Swift Package Manager.

## Features

- URL interception via `URLProtocol`
- Runtime logging toggle (pause/resume interception)
- Thread-safe log storage via `actor`
- FIFO log buffer (default `200`)
- Built-in sensitive data masking (toggleable at runtime)
- SwiftUI inspector dashboard + detail tabs
- Real-time search and status filtering
- URL ignore rules via substring and regex pattern
- Export logs as formatted text or cURL commands
- Activation shortcuts:
  - iOS shake gesture
  - macOS menu bar popover + `Command + Shift + P`

## Install (SPM)

In Xcode:

1. `File` -> `Add Package Dependencies...`
2. Enter your repository URL for Prowl
3. Select dependency rule version:
   - `Up to Next Major Version` (recommended), starting from the latest release
   - `Up to Next Minor Version`
   - `Exact Version` (locked)
4. Add the `Prowl` product to your app target

### Version Strategy Example

- **Stable updates (recommended):** `Up to Next Major` from the latest release tag
- **Strict lock for CI/release:** `Exact` to a specific release tag

If you use `Package.swift` directly, pin like this:

```swift
dependencies: [
    .package(url: "https://github.com/ProwlLabs/prowlkit-ios.git", exact: "<latest-release-tag>")
]
```

## Quick Start

### 1) Start interception

Call this once at app startup:

```swift
import ProwlKit

@main
struct DemoApp: App {
    init() {
        Prowl.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2) Ignore Noise URLs (Optional)

If your app heavily pings telemetry or third-party analytics (like Firebase, Mixpanel, etc.), you can cleanly exclude them from cluttering your Prowl logs.

Pass an array of string partials directly when starting:

```swift
Prowl.start(ignoredURLs: [
    "https://firebaselogging.googleapis.com",
    "https://api.mixpanel.com/",
    "https://app-analytics-services.com/"
])
```

Alternatively, you can dynamically ignore URLs later at runtime:

```swift
Prowl.ignoreURL("https://res.cloudinary.com/")
Prowl.ignoreURL(regex: #"https://api\.example\.com/v[0-9]+/health"#)
```

You can also pass regex rules directly at startup:

```swift
Prowl.start(
    ignoredURLs: ["https://firebaselogging.googleapis.com"],
    ignoredURLRegexes: [#"https://api\.example\.com/internal/.*"#]
)
```

### 3) Open the inspector

No extra view modifier is required.

After `Prowl.start()`:

- iOS: shake device to toggle inspector
- macOS: click the `Prowl` status bar icon and choose inspector actions from the popover panel

You can also control inspector manually (iOS/macOS):

```swift
Prowl.show()
Prowl.hide()
Prowl.toggle()
```

On macOS, `Prowl.start()` automatically installs a menu bar item so you can open/toggle the inspector without embedding a custom debug screen.

## Configure Storage and Masking

`Prowl.configure(...)` is `async` — it awaits the runtime actor so the
configuration is in place before it returns. Always `await` it before calling
`Prowl.start()`:

```swift
import ProwlKit
import ProwlCore

let storage = ProwlStorage(limit: 500)
let masker = SensitiveDataMasker(
    sensitiveHeaders: ["authorization", "cookie", "x-api-key"],
    sensitiveJSONKeys: ["password", "token", "accessToken"]
)

Task { @MainActor in
    await Prowl.configure(storage: storage, masker: masker)
    Prowl.start()
}
```

### Sensitive Data Masking Toggle

Prowl can mask common secrets (for example `Authorization` bearer tokens, cookies, private keys, and common token/password JSON keys). Default is OFF.

You can toggle this at runtime:

```swift
import ProwlKit

Prowl.isSensitiveDataMaskingEnabled = false // default (show raw values)
Prowl.isSensitiveDataMaskingEnabled = true  // redact sensitive values
```

## Endpoint rate alerts (optional)

Flag noisy or critical endpoints when traffic crosses a threshold (per HTTP method + host + path, ignoring the query string). The request that reaches the threshold gets `NetworkLog.endpointRateAlertTriggered == true`, surfaced in the dashboard and detail screen.

```swift
import ProwlKit

Prowl.endpointRateAlertRules = [
    .init(match: .urlContains("https://api.example.com/v1/search"), threshold: 50),
    .init(match: .urlRegularExpression(pattern: #"https://telemetry\.[^/]+/collect"#), threshold: 20)
]

// Counters reset automatically when you clear logs in the inspector, or manually:
Prowl.resetEndpointRateAlertCounters()
```

## Response body transform for logging (optional)

If responses are encrypted or encoded for transport, implement `ProwlResponseBodyLoggingTransforming` to supply **decoded bytes for logging only** (the live `URLSession` response is unchanged). Return `nil` to keep the original payload.

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
        // Decode or decrypt `data` for display in Prowl; return nil to skip.
        nil
    }
}

Prowl.responseBodyLoggingTransformer = MyDecryptor()
Prowl.start()
```

## Stream Request Body Capture

Prowl now follows a body capture path (`httpBody` / `httpBodyStream` / metadata snapshot fallback).  
For best reliability with custom stream builders, you can still attach a snapshot at request-build time:

```swift
import ProwlCore

var request = URLRequest(url: endpoint)
request.httpMethod = "POST"

let payload = try JSONEncoder().encode(body)
request.httpBodyStream = InputStream(data: payload)
request.attachProwlBodySnapshot(payload) // optional reliability hint
```

### URLSession Integration (Automatic + Helpers)

Prowl now installs safe snapshot support at `Prowl.start()` time for:

- `URLSession.uploadTask(with:from:)`
- `URLSession.uploadTask(with:from:completionHandler:)`

That means payloads passed as `Data` are auto-attached as body snapshots for logging.

For streamed uploads, use helper APIs:

```swift
import ProwlCore

var request = URLRequest(url: endpoint)
request.httpMethod = "POST"

let payload = try JSONEncoder().encode(body)
request.setProwlHTTPBodyStream(payload) // stream + snapshot in one call

let task = URLSession.shared.prowlUploadTask(
    withStreamedRequest: request,
    bodySnapshot: payload
)
task.resume()
```

### Alamofire Integration

If you use Alamofire, plug in `ProwlAlamofireBodySnapshotInterceptor` to auto-attach request body snapshots during adaptation:

```swift
import Alamofire
import ProwlCore

let session = Session(
    configuration: .default,
    interceptor: ProwlAlamofireBodySnapshotInterceptor()
)
```

### Moya Integration

If you use Moya, add `ProwlMoyaBodySnapshotPlugin` to provider plugins:

```swift
import Moya
import ProwlCore

let provider = MoyaProvider<MyTarget>(
    plugins: [ProwlMoyaBodySnapshotPlugin()]
)
```

## Toggle Logging at Runtime

```swift
import ProwlKit

Prowl.isLoggingEnabled = false // pause interception
Prowl.isLoggingEnabled = true  // resume interception
```

## Custom URLSessionDelegate (Pinning / mTLS)

You can provide your own `URLSessionDelegate` (for certificate pinning, mTLS, or custom trust handling):

```swift
final class MySessionDelegate: NSObject, URLSessionDelegate {
    // Implement trust / challenge handling here
}

Prowl.customSessionDelegate = MySessionDelegate()
Prowl.start()
```

## Export Logs

In the inspector toolbar:

- **Formatted Text** exports readable full entries
- **cURL Commands** exports executable requests for replay/debugging

Platform behavior:

- iOS uses `UIActivityViewController`
- macOS uses `NSSavePanel`

## Manual Inspector View

If you want to present the inspector yourself:

```swift
import SwiftUI
import ProwlUI

struct DebugPanelHost: View {
    var body: some View {
        ProwlInspectorView()
    }
}
```

## Example App

A complete usage example lives in:

```text
Example/Prowl-example
```

It includes:
- iOS tabs with live API traffic
- macOS menu bar inspector integration
- mock/edit flows and export actions

## Stop Interception

```swift
Prowl.stop()
```

## Upgrade Guide

- Prefer upgrading by immutable tags (`1.0.x`) instead of floating revisions.
- If you hit SPM cache mismatch after tag updates, reset package caches in Xcode and re-resolve packages.
- After upgrading:
  - run your app with `Prowl.isSensitiveDataMaskingEnabled = false` first for parity checks
  - then enable masking in production if needed.

## Troubleshooting

- **CI iOS build fails with `cannot find <symbol> in scope`**  
  Usually caused by access-level changes across package targets. Prefer `package` visibility for cross-target internals.
- **`swift test` passes but iOS package build fails**  
  Run `xcodebuild` package scheme checks locally (same command as CI) because iOS-only paths can be skipped by macOS test runs.
- **SPM tag/revision conflicts**  
  Ensure release tags are immutable and never retag existing versions.

## Public API Policy

- `Prowl` facade remains the main public entrypoint.
- Core internals should stay `package`/`internal` unless there is a clear consumer need.
- Any new public API should be documented in this README and added to `CHANGELOG.md`.

## Release Checklist

Use this checklist before publishing a public tag:

1. Ensure tests pass locally:

```bash
swift test
```

2. Verify CI is green on both configured Xcode lanes (`latest-stable` and pinned lane).
3. Review public API surface (only intentional symbols should remain `public`).
4. Validate docs examples in this `README.md` still match current behavior.
5. Run `swift-format lint -r Sources Tests` and resolve findings.
6. Create an immutable annotated tag and push it:

```bash
git tag -a <version> -m "Release <version>"
git push origin <version>
```

7. Create GitHub release notes using `.github/RELEASE_TEMPLATE.md`.
8. Update `CHANGELOG.md` with release notes summary.

## Notes

- Prowl uses native APIs only (no third-party dependencies).
- Log capture is designed to be idempotent and avoid side effects to host networking behavior.
- `URLProtocol` loop prevention is handled internally.
- Distributed via Swift Package Manager only — no CocoaPods spec is published.
- See `CONTRIBUTING.md` for development guidelines and `SECURITY.md` for disclosure policy.

## Documentation

Full **DocC** documentation ships with the `ProwlKit` target:

| Resource | Path |
| --- | --- |
| Module landing | `Sources/ProwlKit/ProwlKit.docc/ProwlKit.md` |
| Getting Started | `Sources/ProwlKit/ProwlKit.docc/GettingStarted.md` |
| Configuration | `Sources/ProwlKit/ProwlKit.docc/Configuration.md` |
| Advanced Features | `Sources/ProwlKit/ProwlKit.docc/AdvancedFeatures.md` |
| HTTP Client Integrations | `Sources/ProwlKit/ProwlKit.docc/HTTPClientIntegrations.md` |

In Xcode: **Product → Build Documentation**. The [Swift Package Index](https://swiftpackageindex.com) renders the catalogue from tagged releases.

## License

Distributed under the MIT License — see [`LICENSE`](LICENSE).
