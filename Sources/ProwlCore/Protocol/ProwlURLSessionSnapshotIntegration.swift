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
    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest)
    }

    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest, completionHandler: completionHandler)
    }

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
