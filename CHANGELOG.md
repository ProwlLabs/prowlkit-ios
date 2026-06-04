# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-04

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

#### Project & CI
- CI workflow (`ci.yml`) and release validation workflow for tag builds.
- Public-maintainer docs: `CONTRIBUTING.md`, `SECURITY.md`, and GitHub release template.
- Release checklist documented in `README.md`.

[Unreleased]: https://github.com/ProwlKit/prowlkit-ios/compare/1.0.0...HEAD
[1.0.0]: https://github.com/ProwlKit/prowlkit-ios/releases/tag/1.0.0
