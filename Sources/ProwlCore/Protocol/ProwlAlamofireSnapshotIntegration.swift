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

public final class ProwlAlamofireBodySnapshotInterceptor: RequestInterceptor {
    public init() {}

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
