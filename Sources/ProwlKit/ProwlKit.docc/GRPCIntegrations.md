# gRPC Integrations

@Metadata {
    @PageKind(article)
    @TitleHeading("Tutorial")
}

Automatic gRPC Swift 2 client logging via the optional `ProwlGRPC` product.

## Overview

`ProwlGRPC` depends on [gRPC Swift 2](https://github.com/grpc/grpc-swift-2) and
requires **iOS 18+** / **macOS 15+**. Core ProwlKit products stay dependency-free
and support older OS versions; only apps that opt into `ProwlGRPC` pull in
gRPC Swift.

## Add the product

In Xcode, add the **ProwlGRPC** library product from the ProwlKit package to your
app target. In `Package.swift`:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "ProwlKit", package: "prowlkit-ios"),
        .product(name: "ProwlGRPC", package: "prowlkit-ios"),
    ]
)
```

## Register the interceptor

```swift
import GRPCCore
import ProwlGRPC
import ProwlKit

@MainActor
func runGRPCClient(transport: some ClientTransport) async throws {
    Prowl.start()

    try await withGRPCClient(
        transport: transport,
        interceptors: [ProwlGrpcSwiftClientInterceptor.registration()]
    ) { client in
        // Call generated service methods on `client`.
    }
}
```

``ProwlGrpcSwiftClientInterceptor`` captures method name, RPC type, metadata,
timing, status, and request/response payloads (when available).

## Protobuf payloads

By default, messages that conform to `Encodable` are JSON-encoded for the
inspector. For `SwiftProtobuf.Message` types, pass a custom encoder:

```swift
import SwiftProtobuf

let interceptor = ProwlGrpcSwiftClientInterceptor(
    encodeMessage: { message in
        guard let protobuf = message as? any SwiftProtobuf.Message else { return nil }
        return try? protobuf.jsonUTF8Data()
    }
)

let registration = ConditionalInterceptor.apply(interceptor, to: .all)
```

## Manual logging

When you cannot use gRPC Swift 2, or need a custom integration, call
``Prowl/logGrpcCall(fullMethodName:methodType:requestBody:responseBody:grpcStatusCode:errorDescription:startedAt:duration:)``
directly. See <doc:AdvancedFeatures#gRPC-logging>.
