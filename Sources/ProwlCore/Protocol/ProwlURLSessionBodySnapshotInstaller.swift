//
//  ProwlURLSessionBodySnapshotInstaller.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

#if canImport(ObjectiveC)
import ObjectiveC.runtime

enum ProwlURLSessionBodySnapshotInstaller {
    private static let installOnce: Void = {
        swizzleDataTaskWithoutCompletion()
        swizzleDataTaskWithCompletion()
        swizzleUploadTaskWithoutCompletion()
        swizzleUploadTaskWithCompletion()
        swizzleUploadTaskWithStreamedRequest()
    }()

    static func installIfNeeded() {
        _ = installOnce
    }

    private static func swizzleDataTaskWithoutCompletion() {
        let originalSelector = NSSelectorFromString("dataTaskWithRequest:")
        let swizzledSelector = #selector(URLSession.prowl_dataTask(with:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleDataTaskWithCompletion() {
        let originalSelector = NSSelectorFromString("dataTaskWithRequest:completionHandler:")
        let swizzledSelector = #selector(URLSession.prowl_dataTask(with:completionHandler:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleUploadTaskWithoutCompletion() {
        let originalSelector = #selector(URLSession.uploadTask(with:from:))
        let swizzledSelector = #selector(URLSession.prowl_uploadTask(with:from:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleUploadTaskWithCompletion() {
        let originalSelector = #selector(URLSession.uploadTask(with:from:completionHandler:))
        let swizzledSelector = #selector(URLSession.prowl_uploadTask(with:from:completionHandler:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleUploadTaskWithStreamedRequest() {
        let originalSelector = #selector(URLSession.uploadTask(withStreamedRequest:))
        let swizzledSelector = #selector(URLSession.prowl_uploadTask(withStreamedRequest:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleInstanceMethod(
        on cls: AnyClass,
        originalSelector: Selector,
        swizzledSelector: Selector
    ) {
        guard
            let originalMethod = class_getInstanceMethod(cls, originalSelector),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        else {
            return
        }

        let didAdd = class_addMethod(
            cls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAdd {
            class_replaceMethod(
                cls,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

private extension URLSession {
    func prowl_requestByAttachingBodySnapshot(_ request: URLRequest, bodyData: Data?) -> URLRequest {
        guard let bodyData, !bodyData.isEmpty else {
            return request
        }
        if ProwlRequestBodySnapshot.body(from: request) != nil {
            return request
        }
        return request.withProwlBodySnapshot(bodyData)
    }

    func prowl_requestByAttachingBestEffortSnapshot(_ request: URLRequest) -> URLRequest {
        if ProwlRequestBodySnapshot.body(from: request) != nil {
            return request
        }

        if let bodyData = request.httpBody, !bodyData.isEmpty {
            return request.withProwlBodySnapshot(bodyData)
        }

        guard
            let stream = request.httpBodyStream,
            let copyable = stream as? NSCopying,
            let copiedStream = copyable.copy(with: nil) as? InputStream,
            let streamData = prowl_readAllBytes(from: copiedStream),
            !streamData.isEmpty
        else {
            return request
        }

        return request.withProwlBodySnapshot(streamData)
    }

    func prowl_readAllBytes(from stream: InputStream) -> Data? {
        var captured = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        stream.open()
        defer { stream.close() }

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: bufferSize)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            captured.append(buffer, count: count)
        }

        return captured.isEmpty ? nil : captured
    }

    @objc
    func prowl_dataTask(with request: URLRequest) -> URLSessionDataTask {
        let capturedRequest = prowl_requestByAttachingBestEffortSnapshot(request)
        return prowl_dataTask(with: capturedRequest)
    }

    @objc
    func prowl_dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let capturedRequest = prowl_requestByAttachingBestEffortSnapshot(request)
        return prowl_dataTask(with: capturedRequest, completionHandler: completionHandler)
    }

    @objc
    func prowl_uploadTask(with request: URLRequest, from bodyData: Data?) -> URLSessionUploadTask {
        let capturedRequest = prowl_requestByAttachingBodySnapshot(request, bodyData: bodyData)
        return prowl_uploadTask(with: capturedRequest, from: bodyData)
    }

    @objc
    func prowl_uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        let capturedRequest = prowl_requestByAttachingBodySnapshot(request, bodyData: bodyData)
        return prowl_uploadTask(with: capturedRequest, from: bodyData, completionHandler: completionHandler)
    }

    @objc
    func prowl_uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask {
        let capturedRequest = prowl_requestByAttachingBestEffortSnapshot(request)
        return prowl_uploadTask(withStreamedRequest: capturedRequest)
    }
}
#endif
