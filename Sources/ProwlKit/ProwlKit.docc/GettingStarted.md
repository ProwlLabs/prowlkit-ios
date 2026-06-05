# Getting Started

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Install ProwlKit, start interception once at launch, and open the inspector on
device or Mac.

![Animated demo of Prowl inspector on macOS, opened from the menu bar.](Prowl.gif)

## Overview

ProwlKit is designed for debug and internal builds. A single call to
``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` registers URL interception and
installs the platform-specific inspector affordance. You do not embed a view
modifier or debug menu unless you want a custom host screen.

## Add the package

In Xcode: **File → Add Package Dependencies…**, paste your repository URL, and
add the **ProwlKit** product to your app target.

In `Package.swift`, pin to a release tag:

```swift
dependencies: [
    .package(url: "https://github.com/ProwlLabs/prowlkit-ios.git", from: "1.0.0")
]
```

## Start interception

Call ``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` from your app entry point
on the main actor:

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

``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` is idempotent — repeated calls
while already running are ignored.

## Open the inspector

| Platform | Default affordance |
| --- | --- |
| iOS | Shake device |
| macOS | Menu-bar **Prowl** icon → **Open Inspector** (also **⌘⇧P**) |

![Animated demo of Prowl inspector on iPhone — shake to toggle the inspector.](ProwlIphone.gif)

Programmatic control (both platforms):

```swift
Prowl.show()
Prowl.hide()
Prowl.toggle()
```

``Prowl/show()`` and ``Prowl/toggle()`` start interception first if it is not
already running.

## Filter noisy URLs (optional)

Telemetry and analytics endpoints can flood the log. Pass ignore rules at
startup or add them later:

```swift
Prowl.start(ignoredURLs: [
    "https://firebaselogging.googleapis.com",
    "https://api.mixpanel.com/"
])

Prowl.ignoreURL("https://res.cloudinary.com/")
Prowl.ignoreURL(regex: #"https://api\.example\.com/v[0-9]+/health"#)
```

Replace the full rule set by assigning ``Prowl/ignoredURLs`` or
``Prowl/ignoredURLRegexes`` directly.

## Pause and stop

Pause capture without unregistering the protocol:

```swift
Prowl.isLoggingEnabled = false  // pause
Prowl.isLoggingEnabled = true   // resume
```

Tear down interception and inspector affordances (logs in storage are kept):

```swift
Prowl.stop()
```

## Next steps

- <doc:Configuration> — custom storage, masking, and pre-start setup.
- <doc:AdvancedFeatures> — rate alerts, response transforms, certificate pinning.
- <doc:HTTPClientIntegrations> — streamed bodies, Alamofire, and Moya.

## See Also

- ``Prowl``
- ``ProwlInspectorView``
