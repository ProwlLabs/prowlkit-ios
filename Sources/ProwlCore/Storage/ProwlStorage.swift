//
//  ProwlStorage.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public actor ProwlStorage {
    public typealias LogStream = AsyncStream<[NetworkLog]>

    private var logs: [NetworkLog] = []
    private var limit: Int
    private var observers: [UUID: LogStream.Continuation] = [:]

    public init(limit: Int = 200) {
        self.limit = max(limit, 1)
    }

    public func setLimit(_ newLimit: Int) {
        limit = max(newLimit, 1)
        trimToLimit()
        publish()
    }

    public func append(_ log: NetworkLog) {
        logs.append(log)
        trimToLimit()
        publish()
    }

    public func allLogs() -> [NetworkLog] {
        logs
    }

    public func clear() {
        logs.removeAll(keepingCapacity: true)
        publish()
    }

    public func stream() -> LogStream {
        let id = UUID()
        return LogStream { continuation in
            continuation.yield(logs)
            observers[id] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func trimToLimit() {
        guard logs.count > limit else { return }
        logs.removeFirst(logs.count - limit)
    }

    private func publish() {
        for continuation in observers.values {
            continuation.yield(logs)
        }
    }
}
