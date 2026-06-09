//
//  ProwlProtocol.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

package final class ProwlProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.prowlKit.handled"
    private static let requestIDKey = "com.prowlKit.requestID"
    private let lock = NSLock()
    private var cancelled = false
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var metricsDelegate: ProwlMetricsSessionDelegate?

    package override class func canInit(with request: URLRequest) -> Bool {
        guard ProwlRuntime.isLoggingEnabled else {
            return false
        }

        guard let scheme = request.url?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        if let isHandled = URLProtocol.property(forKey: handledKey, in: request) as? Bool, isHandled {
            return false
        }

        if let absoluteString = request.url?.absoluteString,
           ProwlRuntime.shouldIgnore(absoluteString) {
            return false
        }

        return true
    }

    package override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    package override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        URLProtocol.setProperty(UUID().uuidString, forKey: Self.requestIDKey, in: mutableRequest)

        let requestBodyData = Self.captureRequestBodyPreflight(from: request)

        let proxiedRequest = mutableRequest as URLRequest
        let startedAt = Date()

        // Note: building a fresh URLSession per request is intentional —
        // ProwlProtocol filters itself out of the configuration's protocol
        // classes so the proxied request doesn't recurse through Prowl.
        // The cost is small (debugger-only path) and avoids cross-request
        // state leakage from a shared session.
        let config = URLSessionConfiguration.default
        config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != ProwlProtocol.self }

        Task {
            guard !self.isCancelled() else { return }

            switch await ProwlInterceptPipeline.run(
                request: proxiedRequest,
                requestBodyData: requestBodyData,
                startedAt: startedAt
            ) {
            case let .mocked(context, mockRule):
                let delayMs = min(max(mockRule.responseDelayMillis, 0), 60_000)
                if delayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }
                guard !self.isCancelled() else { return }

                let mockURL = context.effectiveRequest.url ?? URL(string: "https://prowl.mock")!
                let mockResponse = HTTPURLResponse(
                    url: mockURL,
                    statusCode: mockRule.mockStatusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: mockRule.mockHeaders
                )

                self.complete(
                    request: context.effectiveRequest,
                    requestBodyData: context.requestBodyData,
                    startedAt: context.startedAt,
                    data: mockRule.mockBody,
                    response: mockResponse,
                    error: nil,
                    requestWasRewritten: context.requestWasRewritten,
                    responseWasMocked: true
                )

            case let .network(context):
                self.forwardToNetwork(
                    effectiveRequest: context.effectiveRequest,
                    effectiveBodyData: context.requestBodyData,
                    startedAt: context.startedAt,
                    requestWasRewritten: context.requestWasRewritten,
                    config: config
                )
            }
        }
    }

    private func forwardToNetwork(
        effectiveRequest: URLRequest,
        effectiveBodyData: Data?,
        startedAt: Date,
        requestWasRewritten: Bool,
        config: URLSessionConfiguration
    ) {
        guard !isCancelled() else { return }

        let metricsDelegate = ProwlMetricsSessionDelegate()
        metricsDelegate.forwardingDelegate = ProwlRuntime.customSessionDelegate
        let newSession = URLSession(
            configuration: config,
            delegate: metricsDelegate,
            delegateQueue: nil
        )

        // Race window: stopLoading may have run before we got here.
        // Store the session under the lock and bail (invalidating) if so.
        let stored: Bool = lock.prowlWithLock {
            guard !cancelled else { return false }
            session = newSession
            self.metricsDelegate = metricsDelegate
            return true
        }
        guard stored else {
            newSession.invalidateAndCancel()
            return
        }

        let task = newSession.dataTask(with: effectiveRequest)
        metricsDelegate.registerHandler(for: task) { [weak self] data, response, error in
            guard let self else { return }
            guard !self.isCancelled() else { return }
            let metrics = ProwlTimingStore.take(forTaskID: task.taskIdentifier)
            self.complete(
                request: effectiveRequest,
                requestBodyData: effectiveBodyData,
                startedAt: startedAt,
                data: data ?? Data(),
                response: response,
                error: error,
                requestWasRewritten: requestWasRewritten,
                responseWasMocked: false,
                timing: metrics.timing,
                hostIp: metrics.hostIp
            )
        }

        let resumed: Bool = lock.prowlWithLock {
            guard !cancelled else { return false }
            dataTask = task
            return true
        }
        guard resumed else {
            task.cancel()
            newSession.invalidateAndCancel()
            return
        }
        task.resume()
    }

    package override func stopLoading() {
        let (taskToCancel, sessionToInvalidate): (URLSessionDataTask?, URLSession?) = lock.prowlWithLock {
            cancelled = true
            let taskCopy = dataTask
            let sessionCopy = session
            dataTask = nil
            session = nil
            metricsDelegate = nil
            return (taskCopy, sessionCopy)
        }
        taskToCancel?.cancel()
        sessionToInvalidate?.invalidateAndCancel()
    }

    private func isCancelled() -> Bool {
        lock.prowlWithLock { cancelled }
    }

    private func complete(
        request: URLRequest,
        requestBodyData: Data?,
        startedAt: Date,
        data: Data,
        response: URLResponse?,
        error: Error?,
        requestWasRewritten: Bool,
        responseWasMocked: Bool,
        timing: RequestTiming? = nil,
        hostIp: String? = nil
    ) {
        // Re-check under lock to guarantee no client? call after stopLoading.
        // URL Loading System contract: client callbacks are undefined behavior
        // after stopLoading returns.
        guard !isCancelled() else { return }

        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        let duration = Date().timeIntervalSince(startedAt)
        let requestHeaders = request.allHTTPHeaderFields ?? [:]
        let responseHeaders = (response as? HTTPURLResponse)?
            .allHeaderFields
            .reduce(into: [String: String]()) { partialResult, pair in
                guard let key = pair.key as? String else { return }
                partialResult[key] = String(describing: pair.value)
            } ?? [:]

        let requestID = (URLProtocol.property(forKey: Self.requestIDKey, in: request) as? String)
            .flatMap(UUID.init(uuidString:))
            ?? UUID()
        let requestURL = request.url
        let requestMethod = request.httpMethod ?? "GET"
        let requestContentType = request.value(forHTTPHeaderField: "Content-Type")
        let responseContentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let timeoutInterval = request.timeoutInterval
        let cachePolicy = Self.cachePolicyName(request.cachePolicy)
        let errorDescription = error?.localizedDescription
        let maskingEnabled = ProwlRuntime.isSensitiveDataMaskingEnabled
        let requestBodyDataToLog = requestBodyData
            ?? Self.captureRequestBodyPostflight(from: request)
        let requestEncoding = requestHeaders["Content-Encoding"]
        let responseEncoding = responseHeaders["Content-Encoding"]

        let decodedRequestData = requestBodyDataToLog.map {
            ProwlBodyDecoder.decodeIfNeeded($0, contentEncoding: requestEncoding)
        }
        var responseDataForLogging = ProwlBodyDecoder.decodeIfNeeded(data, contentEncoding: responseEncoding)
        if let transformer = ProwlRuntime.responseBodyLoggingTransformer {
            if let mapped = transformer.responseBodyForLogging(
                data: responseDataForLogging,
                contentType: responseContentType,
                url: requestURL,
                statusCode: statusCode
            ) {
                responseDataForLogging = mapped
            }
        }

        let requestMultipart = decodedRequestData.map {
            ProwlMultipartParser.parse(body: $0, contentType: requestContentType)
        } ?? []
        let responseMultipart = ProwlMultipartParser.parse(
            body: responseDataForLogging,
            contentType: responseContentType
        )

        Task {
            let runtime = ProwlRuntime.shared
            let snapshot = await runtime.snapshot()

            let rateAlertTriggered = ProwlEndpointRateAlertCoordinator.shared.evaluateAndIncrement(
                method: requestMethod,
                url: requestURL,
                absoluteURLString: requestURL?.absoluteString ?? ""
            )

            let requestHeaders = maskingEnabled
                ? snapshot.masker.mask(headers: requestHeaders)
                : requestHeaders
            let responseHeaders = maskingEnabled
                ? snapshot.masker.mask(headers: responseHeaders)
                : responseHeaders

            let requestBody = maskingEnabled
                ? snapshot.masker.mask(body: decodedRequestData, contentType: requestContentType)
                : decodedRequestData.map { NetworkLog.Body(data: $0, contentType: requestContentType) }
            let responseBody = maskingEnabled
                ? snapshot.masker.mask(body: responseDataForLogging, contentType: responseContentType)
                : NetworkLog.Body(data: responseDataForLogging, contentType: responseContentType)

            let log = NetworkLog(
                requestID: requestID,
                url: requestURL,
                method: requestMethod,
                requestHeaders: requestHeaders,
                requestBody: requestBody,
                responseHeaders: responseHeaders,
                responseBody: responseBody,
                statusCode: statusCode,
                startedAt: startedAt,
                duration: duration,
                timeoutInterval: timeoutInterval,
                cachePolicy: cachePolicy,
                errorDescription: errorDescription,
                endpointRateAlertTriggered: rateAlertTriggered,
                hostIp: hostIp,
                networkProtocol: .http,
                timing: timing,
                requestMultipartParts: requestMultipart,
                responseMultipartParts: responseMultipart,
                requestRewritten: requestWasRewritten,
                responseMocked: responseWasMocked
            )

            await snapshot.storage.append(log)
        }
    }

    private static func captureRequestBodyBestEffort(from request: URLRequest) -> Data? {
        if let body = request.httpBody, !body.isEmpty {
            return body
        }

        guard
            let stream = request.httpBodyStream,
            let copyable = stream as? NSCopying,
            let copiedStream = copyable.copy(with: nil) as? InputStream
        else {
            return nil
        }

        return readAllBytes(from: copiedStream)
    }

    package static func captureRequestBodyPreflight(from request: URLRequest) -> Data? {
        if let bestEffort = captureRequestBodyBestEffort(from: request) {
            return bestEffort
        }

        if let snapshotBody = ProwlRequestBodySnapshot.body(from: request), !snapshotBody.isEmpty {
            return snapshotBody
        }

        return nil
    }

    private static func captureRequestBodyPostflight(from request: URLRequest) -> Data? {
        if let stream = request.httpBodyStream,
           let streamBody = readAllBytes(from: stream),
           !streamBody.isEmpty {
            return streamBody
        }
        if let snapshotBody = ProwlRequestBodySnapshot.body(from: request), !snapshotBody.isEmpty {
            return snapshotBody
        }

        if let body = request.httpBody, !body.isEmpty {
            return body
        }
        return nil
    }

    private static func readAllBytes(from stream: InputStream) -> Data? {
        var captured = Data()
        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            captured.append(buffer, count: readCount)
        }

        return captured.isEmpty ? nil : captured
    }

    private static func cachePolicyName(_ policy: URLRequest.CachePolicy) -> String {
        switch policy {
        case .useProtocolCachePolicy:
            return "UseProtocolCachePolicy"
        case .reloadIgnoringLocalCacheData:
            return "ReloadIgnoringLocalCacheData"
        case .reloadIgnoringLocalAndRemoteCacheData:
            return "ReloadIgnoringLocalAndRemoteCacheData"
        case .returnCacheDataElseLoad:
            return "ReturnCacheDataElseLoad"
        case .returnCacheDataDontLoad:
            return "ReturnCacheDataDontLoad"
        case .reloadRevalidatingCacheData:
            return "ReloadRevalidatingCacheData"
        @unknown default:
            return String(describing: policy)
        }
    }
}
