//  
//  ProwlMoyaSnapshotIntegration.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

#if canImport(Moya)
import Moya

/// Moya `PluginType` that attaches request bodies to Prowl as snapshots.
///
/// Plug into your `MoyaProvider`'s `plugins` array so Prowl can display
/// payloads that Moya assembles via its `Task` cases.
public struct ProwlMoyaBodySnapshotPlugin: PluginType {
    public init() {}

    /// Returns the request unchanged if a snapshot is already present;
    /// otherwise attaches `httpBody` or the `Task`-derived body data.
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        if let existing = ProwlRequestBodySnapshot.body(from: request), !existing.isEmpty {
            return request
        }

        if let requestBody = request.httpBody, !requestBody.isEmpty {
            return request.withProwlBodySnapshot(requestBody)
        }

        guard let taskBody = bodyData(from: target.task), !taskBody.isEmpty else {
            return request
        }
        return request.withProwlBodySnapshot(taskBody)
    }

    private func bodyData(from task: Task) -> Data? {
        switch task {
        case let .requestData(data):
            return data
        case let .requestCompositeData(data, _):
            return data
        default:
            return nil
        }
    }
}
#endif
