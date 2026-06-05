# ``ProwlKit``

@Metadata {
    @DisplayName("ProwlKit")
    @TitleHeading("Framework")
    @Available(iOS, introduced: "15.0")
    @Available(iPadOS, introduced: "15.0")
    @Available(macOS, introduced: "12.0")
    @Available(watchOS, introduced: "8.0")
    @Available(tvOS, introduced: "15.0")
    @Available(visionOS, introduced: "1.0")
    @SupportedLanguage(swift)
}

Debug and inspect network traffic in your apps with URL interception, sensitive-data
masking, and a built-in SwiftUI inspector.

![Animated demo of Prowl inspector on macOS, capturing and inspecting live requests.](Prowl.gif)

## Overview

ProwlKit installs a `URLProtocol` at startup and captures every HTTP/HTTPS
request that flows through `URLSession`. Captured logs live in a thread-safe
FIFO buffer, can be masked for sensitive headers and JSON keys, and appear in
a SwiftUI inspector (``ProwlInspectorView``) that you open with a shake on iOS
or from the menu-bar icon on macOS.

The library ships three SPM products:

| Product | Use when |
| --- | --- |
| **ProwlKit** | You want the full experience: ``Prowl`` facade, inspector UI, and core types re-exported. |
| **ProwlCore** | You only need interception, storage, masking, and formatting — no SwiftUI. |
| **ProwlUI** | You embed ``ProwlInspectorView`` yourself and manage ``ProwlStorage`` separately. |

Requires Swift 6.2+. No third-party dependencies.

### Inspector on macOS

![Prowl inspector dashboard on macOS with filters, status chips, and timeline.](Prowl2.png)

![Prowl inspector detail view on macOS with headers and body, ready for export or mocking.](Prowl3.png)

![Prowl menu bar badge icon used to open the inspector from anywhere on macOS.](ProwlBadge.png)

### Inspector on iOS

![Animated demo of Prowl inspector on iPhone, shake to open and inspect live traffic.](ProwlIphone.gif)

![Prowl inspector list view on iPhone, showing captured requests and status colors.](Shot.png)

![Prowl inspector detail sheet on iPhone with request/response breakdown.](Shot-2.png)

### Quick start

```swift
import ProwlKit

@main
struct DemoApp: App {
    init() {
        Prowl.start()
    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

After ``Prowl/start(ignoredURLs:ignoredURLRegexes:)``:

- **iOS** — shake the device to toggle the inspector.
- **macOS** — click the **Prowl** menu-bar item (shortcut: **⌘⇧P**).

### How interception works

1. ``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` registers `ProwlProtocol` and
   enables platform inspector affordances.
2. Matching `URLSession` traffic is mirrored into ``NetworkLog`` entries and
   appended to ``ProwlStorage``.
3. Optional ``SensitiveDataMasker`` redacts secrets before storage.
4. ``ProwlInspectorView`` observes storage and renders search, filters, detail
   tabs, export, and mock editing.

Loop prevention and side-effect-free forwarding to the real network stack are
handled inside the package — your app’s networking behavior stays unchanged.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Configuration>
- <doc:AdvancedFeatures>
- <doc:HTTPClientIntegrations>

### Entry point

- ``Prowl``

### Captured data

- ``NetworkLog``
- ``NetworkLog/Body``
- ``ProwlStorage``

### Privacy and display

- ``SensitiveDataMasker``
- ``ProwlResponseBodyLoggingTransforming``

### Traffic analysis

- ``ProwlEndpointRateAlerts``
- ``ProwlEndpointRateAlertRule``
- ``ProwlEndpointRateAlertRule/Match``

### Request body capture

- ``ProwlRequestBodySnapshot``
- <doc:HTTPClientIntegrations>

### Third-party HTTP clients

See <doc:HTTPClientIntegrations> for Alamofire and Moya setup (symbols available when those packages are linked to your target).

### Export and formatting

- ``ProwlLogFormatter``
- ``ProwlExportFormat``

### Inspector UI

- ``ProwlInspectorView``
- ``ProwlLogDetailView``
- ``ProwlLogDetailView/Tab``
