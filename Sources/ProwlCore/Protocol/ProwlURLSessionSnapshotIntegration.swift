//
//  ProwlURLSessionSnapshotIntegration.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public extension URLSession {
    /// Like `dataTask(with:)`, but attaches a body snapshot for inspector display.
    ///
    /// If `bodySnapshot` is `nil` or empty, falls back to a plain data task.
    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest)
    }

    /// Like `dataTask(with:completionHandler:)`, but attaches a body snapshot.
    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest, completionHandler: completionHandler)
    }

    /// Like `uploadTask(withStreamedRequest:)`, but attaches a body snapshot so
    /// the streamed payload is visible in the inspector.
    func prowlUploadTask(
        withStreamedRequest request: URLRequest,
        bodySnapshot: Data
    ) -> URLSessionUploadTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return uploadTask(withStreamedRequest: capturedRequest)
    }

    private func prowlRequestWithSnapshot(from request: URLRequest, bodySnapshot: Data?) -> URLRequest {
        guard let bodySnapshot, !bodySnapshot.isEmpty else {
            return request
        }
        if ProwlRequestBodySnapshot.body(from: request) != nil {
            return request
        }
        return request.withProwlBodySnapshot(bodySnapshot)
    }
}
