# HTTP Client Integrations

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Capture request bodies from streams, uploads, Alamofire, and Moya.

## Overview

Prowl reads `httpBody`, `httpBodyStream`, and metadata when the URL Loading
System still exposes them. Streamed uploads consume the body once — attach a
**body snapshot** so the inspector shows what was actually sent.

``Prowl/start(ignoredURLs:ignoredURLRegexes:)`` also installs automatic snapshot
support for `URLSession.uploadTask(with:from:)` variants (payload `Data` is
attached for logging).

## Manual snapshots

```swift
import ProwlCore

var request = URLRequest(url: endpoint)
request.httpMethod = "POST"

let payload = try JSONEncoder().encode(body)
request.httpBodyStream = InputStream(data: payload)
request.attachProwlBodySnapshot(payload)
```

Convenience helpers on `URLRequest`:

- `setProwlHTTPBodyStream(_:)` — stream + snapshot in one call.
- `withProwlBodySnapshot(_:)` — non-mutating copy.
- `attachProwlJSONBodySnapshot(_:encoder:)` — encode `Encodable` values.

Low-level API: ``ProwlRequestBodySnapshot/attach(_:to:)`` and
``ProwlRequestBodySnapshot/body(from:)``.

## URLSession helpers

```swift
import ProwlCore

let task = URLSession.shared.prowlUploadTask(
    withStreamedRequest: request,
    bodySnapshot: payload
)
task.resume()
```

`URLSession.prowlDataTask(with:bodySnapshot:)` mirrors `dataTask` with an
optional snapshot parameter.

## Alamofire

Add `ProwlAlamofireBodySnapshotInterceptor` to your `Session` (requires
Alamofire linked to the target):

```swift
import Alamofire
import ProwlCore

let session = Session(
    configuration: .default,
    interceptor: ProwlAlamofireBodySnapshotInterceptor()
)
```

The interceptor runs at adapt time and copies `httpBody` into a snapshot when
one is not already present.

## Moya

Add `ProwlMoyaBodySnapshotPlugin` to your provider plugins (requires Moya):

```swift
import Moya
import ProwlCore

let provider = MoyaProvider<MyTarget>(
    plugins: [ProwlMoyaBodySnapshotPlugin()]
)
```

The plugin captures `httpBody` or `Task`-derived `.requestData` /
`.requestCompositeData` payloads.

## See Also

- ``ProwlRequestBodySnapshot``
- ``ProwlRequestBodySnapshot/attach(_:to:)``
- <doc:GettingStarted>
