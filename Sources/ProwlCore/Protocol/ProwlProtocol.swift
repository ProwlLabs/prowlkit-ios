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

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?

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

        let config = URLSessionConfiguration.default
        config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != ProwlProtocol.self }

        Task {
            if let mockRule = await ProwlMocker.shared.findMatch(for: proxiedRequest) {
                let mockURL = proxiedRequest.url ?? URL(string: "https://prowl.mock")!
                let mockResponse = HTTPURLResponse(url: mockURL, statusCode: mockRule.mockStatusCode, httpVersion: "HTTP/1.1", headerFields: mockRule.mockHeaders)
                
                self.complete(
                    request: proxiedRequest,
                    requestBodyData: requestBodyData,
                    startedAt: startedAt,
                    data: mockRule.mockBody,
                    response: mockResponse,
                    error: nil
                )
                return
            }
            
            self.session = URLSession(configuration: config, delegate: ProwlRuntime.customSessionDelegate, delegateQueue: nil)
            self.dataTask = self.session?.dataTask(with: proxiedRequest) { [weak self] data, response, error in
                guard let self else { return }
                self.complete(
                    request: proxiedRequest,
                    requestBodyData: requestBodyData,
                    startedAt: startedAt,
                    data: data ?? Data(),
                    response: response,
                    error: error
                )
            }
            self.dataTask?.resume()
        }
    }

    package override func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        dataTask = nil
        session = nil
    }
    
    private func complete(
        request: URLRequest,
        requestBodyData: Data?,
        startedAt: Date,
        data: Data,
        response: URLResponse?,
        error: Error?
    ) {
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

        Task {
            let runtime = ProwlRuntime.shared
            let snapshot = await runtime.snapshot()

            var responseDataForLogging = data
            if let transformer = ProwlRuntime.responseBodyLoggingTransformer {
                if let mapped = transformer.responseBodyForLogging(
                    data: data,
                    contentType: responseContentType,
                    url: requestURL,
                    statusCode: statusCode
                ) {
                    responseDataForLogging = mapped
                }
            }

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
                ? snapshot.masker.mask(body: requestBodyDataToLog, contentType: requestContentType)
                : requestBodyDataToLog.map { NetworkLog.Body(data: $0, contentType: requestContentType) }
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
                endpointRateAlertTriggered: rateAlertTriggered
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

    private static func captureRequestBodyPreflight(from request: URLRequest) -> Data? {
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
