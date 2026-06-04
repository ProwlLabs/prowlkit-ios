//
//  ProwlAlamofireSnapshotIntegration.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

#if canImport(Alamofire)
import Alamofire

/// Alamofire `RequestInterceptor` that attaches request bodies to Prowl as
/// snapshots during adaptation.
///
/// Plug into an Alamofire `Session` so Prowl can display request payloads that
/// Alamofire builds via its parameter encoders.
public final class ProwlAlamofireBodySnapshotInterceptor: RequestInterceptor {
    public init() {}

    /// Forwards the request unchanged if it already has a snapshot or no body;
    /// otherwise attaches the `httpBody` as a snapshot and returns the copy.
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping @Sendable (Result<URLRequest, any Error>) -> Void
    ) {
        guard
            ProwlRequestBodySnapshot.body(from: urlRequest) == nil,
            let body = urlRequest.httpBody,
            !body.isEmpty
        else {
            completion(.success(urlRequest))
            return
        }

        completion(.success(urlRequest.withProwlBodySnapshot(body)))
    }
}
#endif
