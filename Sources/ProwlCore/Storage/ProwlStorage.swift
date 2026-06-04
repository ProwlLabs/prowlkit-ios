//
//  ProwlStorage.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

/// Thread-safe FIFO buffer of captured `NetworkLog` entries.
///
/// Backed by an actor so reads and writes are serialized. Observers can
/// subscribe to a live `AsyncStream<[NetworkLog]>` that re-emits on every
/// mutation.
public actor ProwlStorage {
    /// AsyncStream type yielding the full log array on every change.
    public typealias LogStream = AsyncStream<[NetworkLog]>

    private var logs: [NetworkLog] = []
    private var limit: Int
    private var observers: [UUID: LogStream.Continuation] = [:]

    /// Creates a new storage with a FIFO size cap.
    ///
    /// - Parameter limit: Maximum number of logs to retain. Values below 1
    ///   are clamped to 1. Default is `200`.
    public init(limit: Int = 200) {
        self.limit = max(limit, 1)
    }

    /// Updates the FIFO cap and trims existing logs to fit.
    ///
    /// All active stream observers receive the trimmed log set.
    public func setLimit(_ newLimit: Int) {
        limit = max(newLimit, 1)
        trimToLimit()
        publish()
    }

    /// Appends a log entry, trimming the oldest if the buffer is full.
    public func append(_ log: NetworkLog) {
        logs.append(log)
        trimToLimit()
        publish()
    }

    /// Returns a snapshot of all currently retained logs.
    public func allLogs() -> [NetworkLog] {
        logs
    }

    /// Drops every log and notifies observers with an empty array.
    public func clear() {
        logs.removeAll(keepingCapacity: true)
        publish()
    }

    /// Returns an async stream that emits the full log array on every change.
    ///
    /// The first value is the current snapshot; subsequent values arrive on
    /// `append`, `clear`, or `setLimit`.
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
