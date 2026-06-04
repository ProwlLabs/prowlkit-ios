@Metadata {
    @DisplayName("ProwlKit")
}

# ``ProwlKit``

A lightweight network debugger for Apple platforms — interception, logging,
masking, mocking, and a SwiftUI inspector — distributed via Swift Package
Manager.

## Overview

ProwlKit installs a `URLProtocol` at startup and captures every HTTP/HTTPS
request that flows through `URLSession`. Captured logs are held in a
thread-safe FIFO buffer, optionally masked for sensitive headers and JSON
keys, and surfaced in a SwiftUI inspector (`ProwlInspectorView`) reachable via
a shake gesture on iOS or the menu-bar icon on macOS.

Quick start:

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

## Topics

### Entry point

- ``Prowl``

### Storage and models

- ``ProwlStorage``
- ``NetworkLog``

### Masking and transforms

- ``SensitiveDataMasker``
- ``ProwlResponseBodyLoggingTransforming``

### Endpoint rate alerts

- ``ProwlEndpointRateAlerts``
- ``ProwlEndpointRateAlertRule``

### Request body snapshots

- ``ProwlRequestBodySnapshot``

### Inspector UI

- ``ProwlInspectorView``
