# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Released]

### Added

- Optional `ProwlGRPC` SPM product with `ProwlGrpcSwiftClientInterceptor` for gRPC Swift 2 (iOS 18+, macOS 15+).

## [1.0.4] - 2026-06-04

Initial public release of ProwlKit.

### Added

#### Core
- `URLProtocol`-based network interception with internal loop prevention.
- Thread-safe log storage via `actor` with FIFO buffer (default `200`, configurable through `ProwlStorage(limit:)`).
- Runtime toggles: `Prowl.isLoggingEnabled` (pause/resume interception) and `Prowl.isSensitiveDataMaskingEnabled` (default OFF).
- Built-in `SensitiveDataMasker` for headers (e.g. `authorization`, `cookie`, `x-api-key`) and JSON keys (e.g. `password`, `token`, `accessToken`).
- URL ignore rules via substring (`Prowl.ignoreURL(_:)`) and regex (`Prowl.ignoreURL(regex:)`); also accepted at startup via `Prowl.start(ignoredURLs:ignoredURLRegexes:)`.
- Endpoint rate alerts (`Prowl.endpointRateAlertRules`) per HTTP method + host + path with `urlContains` and `urlRegularExpression` matchers; `Prowl.resetEndpointRateAlertCounters()` and auto-reset on log clear.
- Response body logging transform hook (`ProwlResponseBodyLoggingTransforming`) for decoding/decrypting payloads for display only.
- Custom `URLSessionDelegate` injection (`Prowl.customSessionDelegate`) for pinning / mTLS / custom trust handling.
- `Prowl.version` accessor for runtime version reporting.

#### Request body capture
- Body capture path covering `httpBody`, `httpBodyStream`, and metadata snapshot fallback.
- `URLRequest.attachProwlBodySnapshot(_:)` and `URLRequest.setProwlHTTPBodyStream(_:)` helpers.
- Automatic snapshot support installed at `Prowl.start()` for `URLSession.uploadTask(with:from:)` and `URLSession.uploadTask(with:from:completionHandler:)`.
- `URLSession.prowlUploadTask(withStreamedRequest:bodySnapshot:)` helper for streamed uploads.
- Alamofire integration via `ProwlAlamofireBodySnapshotInterceptor`.
- Moya integration via `ProwlMoyaBodySnapshotPlugin`.

#### Inspector UI (`ProwlUI`)
- SwiftUI inspector dashboard with detail tabs, real-time search, and status filtering.
- Log detail view and mock/edit editor flows.
- Manual presentation via `ProwlInspectorView`.
- Export logs as formatted text or executable cURL commands (`UIActivityViewController` on iOS, `NSSavePanel` on macOS).
- Activation shortcuts: iOS shake gesture; macOS menu bar popover and `Command + Shift + P`.
- Programmatic control: `Prowl.show()`, `Prowl.hide()`, `Prowl.toggle()`.

#### Packaging
- Distributed via Swift Package Manager with three products: `ProwlKit` (facade), `ProwlCore` (interception + helpers), `ProwlUI` (SwiftUI inspector).
- Supports iOS 15+, macOS, watchOS, tvOS, and visionOS; built with Swift 6.2.
- No third-party dependencies — uses native `Foundation` + `SwiftUI` only.
- Example app at `Example/Prowl-example` covering iOS tabs, macOS menu bar integration, and mock/edit flows.

#### Documentation
- MIT `LICENSE` at the repository root.
- DocC catalogue at `Sources/ProwlKit/ProwlKit.docc` with a topic-grouped landing page.
- `///` doc comments on every public symbol in `ProwlKit`, `ProwlCore`, and `ProwlUI`.
- `.swift-format` config at the repository root with Swift 6.2-friendly defaults.

#### Project & CI
- CI workflow (`ci.yml`) and release validation workflow for tag builds.
- iOS compatibility matrix builds against deployment targets 15, 16, 17, 18, and 26.
- Public-maintainer docs: `CONTRIBUTING.md`, `SECURITY.md`, and GitHub release template.
- Release checklist documented in `README.md`.

### Changed
- `Prowl.configure(...)` is now `async` and awaits the runtime actor, removing the race where a subsequent `Prowl.start()` could observe stale configuration.

### Fixed
- `ProwlProtocol` could call `client?.urlProtocol(...)` after `stopLoading` returned (undefined behavior per the URL Loading System contract). Added a lock-guarded `cancelled` flag checked before every client callback and before storing the session / data task.
- Endpoint rate alert tests no longer race on the shared singleton — both tests are now in a `.serialized` suite.

### Removed
- `Prowl.version` and the "Check Version" section of the README. Swift Package Manager does not expose tag/version info to library code at runtime, so the hard-coded string was guaranteed to drift from real releases.

[Unreleased]: https://github.com/ProwlLabs/prowlkit-ios/compare/1.0.0...HEAD
[1.0.0]: https://github.com/ProwlLabs/prowlkit-ios/releases/tag/1.0.0
