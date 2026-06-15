//
//  ProwlGrpcSwiftClientInterceptor.swift
//  ProwlGRPC
//

import Foundation
import GRPCCore
import ProwlCore

/// gRPC Swift 2 client interceptor that records RPCs in the Prowl inspector.
///
/// Register with ``ConditionalInterceptor/apply(_:to:)`` when creating a
/// ``GRPCClient``. Requires gRPC Swift 2 (iOS 18+, macOS 15+).
///
/// ```swift
/// import GRPCCore
/// import ProwlGRPC
///
/// try await withGRPCClient(
///     transport: transport,
///     interceptors: [ProwlGrpcSwiftClientInterceptor.registration()]
/// ) { client in
///     // invoke generated service methods
/// }
/// ```
@available(gRPCSwift 2.0, *)
public struct ProwlGrpcSwiftClientInterceptor: ClientInterceptor {
    public typealias MessageEncoder = @Sendable (Any) -> Data?

    private let captureBodies: Bool
    private let maxBodyBytes: Int
    private let encodeMessage: MessageEncoder

    /// Creates an interceptor that forwards captured RPCs to ``ProwlGrpcLogger``.
    ///
    /// - Parameters:
    ///   - captureBodies: When `false`, only metadata, status, and timing are logged.
    ///   - maxBodyBytes: Maximum combined request/response payload size per RPC.
    ///   - encodeMessage: Encodes protobuf or other message types to `Data` for display.
    ///     Defaults to JSON for `Encodable` values and `String(describing:)` otherwise.
    public init(
        captureBodies: Bool = true,
        maxBodyBytes: Int = 256 * 1024,
        encodeMessage: @escaping MessageEncoder = ProwlGrpcSwiftClientInterceptor.defaultEncodeMessage
    ) {
        self.captureBodies = captureBodies
        self.maxBodyBytes = max(0, maxBodyBytes)
        self.encodeMessage = encodeMessage
    }

    /// Default encoder used by ``init(captureBodies:maxBodyBytes:encodeMessage:)``.
    public static func defaultEncodeMessage(_ message: Any) -> Data? {
        ProwlGrpcMessageEncoding.defaultEncode(message)
    }

    /// Registers this interceptor for all RPCs on a gRPC Swift client.
    public static func registration(
        captureBodies: Bool = true,
        maxBodyBytes: Int = 256 * 1024,
        encodeMessage: @escaping MessageEncoder = ProwlGrpcSwiftClientInterceptor.defaultEncodeMessage
    ) -> ConditionalInterceptor<any ClientInterceptor> {
        ConditionalInterceptor.apply(
            ProwlGrpcSwiftClientInterceptor(
                captureBodies: captureBodies,
                maxBodyBytes: maxBodyBytes,
                encodeMessage: encodeMessage
            ),
            to: .all
        )
    }

    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingClientRequest<Input>,
        context: ClientContext,
        next: @concurrent (
            _ request: StreamingClientRequest<Input>,
            _ context: ClientContext
        ) async throws -> StreamingClientResponse<Output>
    ) async throws -> StreamingClientResponse<Output> {
        let startedAt = Date()
        let methodName = context.descriptor.fullyQualifiedMethod
        let methodType = ProwlGrpcSwiftSupport.methodType(for: context.descriptor)
        let requestHeaders = ProwlGrpcSwiftSupport.metadataHeaders(request.metadata)
        let hostIp = ProwlGrpcSwiftSupport.remotePeer(from: context)

        let requestCollector = MessageCollector<Input>()
        let loggingRequest: StreamingClientRequest<Input>

        if captureBodies {
            loggingRequest = StreamingClientRequest(of: Input.self, metadata: request.metadata) { writer in
                let capturingWriter = CapturingRPCWriter(downstream: writer) { message in
                    requestCollector.append(message)
                }
                try await request.producer(RPCWriter(wrapping: capturingWriter))
            }
        } else {
            loggingRequest = request
        }

        let response: StreamingClientResponse<Output>
        do {
            response = try await next(loggingRequest, context)
        } catch {
            let duration = Date().timeIntervalSince(startedAt)
            let requestBody = encodedBody(from: requestCollector.values)
            await ProwlGrpcLogger.logCall(
                fullMethodName: methodName,
                methodType: methodType,
                requestBody: requestBody,
                statusCode: nil,
                errorDescription: String(describing: error),
                startedAt: startedAt,
                duration: duration,
                requestHeaders: requestHeaders,
                hostIp: hostIp
            )
            throw error
        }

        switch response.accepted {
        case let .failure(error):
            let duration = Date().timeIntervalSince(startedAt)
            let requestBody = encodedBody(from: requestCollector.values)
            let statusCode = ProwlGrpcLogger.mapGrpcStatusToHTTP(
                ProwlGrpcSwiftSupport.grpcStatusCode(from: error)
            )
            await ProwlGrpcLogger.logCall(
                fullMethodName: methodName,
                methodType: methodType,
                requestBody: requestBody,
                statusCode: statusCode,
                errorDescription: error.message,
                startedAt: startedAt,
                duration: duration,
                requestHeaders: requestHeaders,
                responseHeaders: ProwlGrpcSwiftSupport.metadataHeaders(error.metadata),
                hostIp: hostIp
            )
            return response

        case let .success(contents):
            guard captureBodies else {
                let duration = Date().timeIntervalSince(startedAt)
                let requestBody = encodedBody(from: requestCollector.values)
                await ProwlGrpcLogger.logCall(
                    fullMethodName: methodName,
                    methodType: methodType,
                    requestBody: requestBody,
                    statusCode: ProwlGrpcLogger.mapGrpcStatusToHTTP(0),
                    startedAt: startedAt,
                    duration: duration,
                    requestHeaders: requestHeaders,
                    responseHeaders: ProwlGrpcSwiftSupport.metadataHeaders(contents.metadata),
                    hostIp: hostIp
                )
                return response
            }

            let loggingSequence = CapturingBodyPartsSequence(
                base: contents.bodyParts,
                startedAt: startedAt,
                methodName: methodName,
                methodType: methodType,
                requestHeaders: requestHeaders,
                initialResponseHeaders: ProwlGrpcSwiftSupport.metadataHeaders(contents.metadata),
                requestBody: encodedBody(from: requestCollector.values),
                hostIp: hostIp,
                maxBodyBytes: maxBodyBytes,
                encodeMessage: encodeMessage
            )

            return StreamingClientResponse(
                accepted: .success(
                    .init(
                        metadata: contents.metadata,
                        bodyParts: RPCAsyncSequence(wrapping: loggingSequence)
                    )
                )
            )
        }
    }

    private func encodedBody<Message>(from messages: [Message]) -> Data? {
        guard captureBodies, !messages.isEmpty else { return nil }
        let chunks = messages.compactMap { encodeMessage($0) }
        return ProwlGrpcMessageEncoding.combine(chunks, maxBytes: maxBodyBytes)
    }
}

@available(gRPCSwift 2.0, *)
private struct CapturingRPCWriter<Element: Sendable>: RPCWriterProtocol {
    let downstream: RPCWriter<Element>
    let onWrite: @Sendable (Element) -> Void

    func write(_ element: Element) async throws {
        onWrite(element)
        try await downstream.write(element)
    }

    func write(contentsOf elements: some Sequence<Element>) async throws {
        for element in elements {
            try await write(element)
        }
    }
}

@available(gRPCSwift 2.0, *)
private struct CapturingBodyPartsSequence<Output: Sendable>: AsyncSequence, Sendable {
    typealias BodyPart = StreamingClientResponse<Output>.Contents.BodyPart
    typealias Element = BodyPart
    typealias AsyncIterator = Iterator

    let base: RPCAsyncSequence<BodyPart, any Error>
    let startedAt: Date
    let methodName: String
    let methodType: String
    let requestHeaders: [String: String]
    let initialResponseHeaders: [String: String]
    let requestBody: Data?
    let hostIp: String?
    let maxBodyBytes: Int
    let encodeMessage: ProwlGrpcSwiftClientInterceptor.MessageEncoder

    struct Iterator: AsyncIteratorProtocol {
        var base: RPCAsyncSequence<BodyPart, any Error>.AsyncIterator
        let startedAt: Date
        let methodName: String
        let methodType: String
        let requestHeaders: [String: String]
        let initialResponseHeaders: [String: String]
        let requestBody: Data?
        let hostIp: String?
        let maxBodyBytes: Int
        let encodeMessage: ProwlGrpcSwiftClientInterceptor.MessageEncoder
        var responseMessages: [Output] = []
        var trailingMetadata: Metadata = [:]
        var logged = false

        mutating func next() async throws -> BodyPart? {
            do {
                guard let part = try await base.next() else {
                    try await logIfNeeded(statusCode: 0, errorDescription: nil)
                    return nil
                }

                switch part {
                case let .message(message):
                    responseMessages.append(message)
                case let .trailingMetadata(metadata):
                    trailingMetadata = metadata
                }

                return part
            } catch let error as RPCError {
                try await logIfNeeded(
                    statusCode: ProwlGrpcSwiftSupport.grpcStatusCode(from: error),
                    errorDescription: error.message,
                    responseHeaders: mergedResponseHeaders(trailingMetadata: error.metadata)
                )
                throw error
            } catch {
                try await logIfNeeded(
                    statusCode: 2,
                    errorDescription: String(describing: error),
                    responseHeaders: mergedResponseHeaders(trailingMetadata: trailingMetadata)
                )
                throw error
            }
        }

        private func mergedResponseHeaders(trailingMetadata: Metadata) -> [String: String] {
            var headers = initialResponseHeaders
            for (key, value) in ProwlGrpcSwiftSupport.metadataHeaders(trailingMetadata) {
                headers[key] = value
            }
            return headers
        }

        private mutating func logIfNeeded(
            statusCode: Int,
            errorDescription: String?,
            responseHeaders: [String: String]? = nil
        ) async throws {
            guard !logged else { return }
            logged = true

            let chunks = responseMessages.compactMap { encodeMessage($0) }
            let responseBody = ProwlGrpcMessageEncoding.combine(chunks, maxBytes: maxBodyBytes)
            let headers = responseHeaders ?? mergedResponseHeaders(trailingMetadata: trailingMetadata)

            await ProwlGrpcLogger.logCall(
                fullMethodName: methodName,
                methodType: methodType,
                requestBody: requestBody,
                responseBody: responseBody,
                statusCode: ProwlGrpcLogger.mapGrpcStatusToHTTP(statusCode),
                errorDescription: errorDescription,
                startedAt: startedAt,
                duration: Date().timeIntervalSince(startedAt),
                requestHeaders: requestHeaders,
                responseHeaders: headers,
                hostIp: hostIp
            )
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(
            base: base.makeAsyncIterator(),
            startedAt: startedAt,
            methodName: methodName,
            methodType: methodType,
            requestHeaders: requestHeaders,
            initialResponseHeaders: initialResponseHeaders,
            requestBody: requestBody,
            hostIp: hostIp,
            maxBodyBytes: maxBodyBytes,
            encodeMessage: encodeMessage
        )
    }
}

@available(gRPCSwift 2.0, *)
private final class MessageCollector<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Element] = []

    func append(_ message: Element) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(message)
    }

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
