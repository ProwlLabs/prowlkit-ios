//
//  ProwlInspectorViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

@MainActor
final class ProwlInspectorViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var statusFilter: ProwlStatusCategory = .all
    @Published var contentTypeFilter: ProwlContentTypeCategory = .all
    @Published private(set) var logs: [NetworkLog] = []

    private var streamTask: Task<Void, Never>?
    private let explicitStorage: ProwlStorage?

    init(storage: ProwlStorage? = nil) {
        self.explicitStorage = storage
        streamTask = Task { [weak self] in
            guard let self else { return }

            let resolvedStorage: ProwlStorage
            if let storage {
                resolvedStorage = storage
            } else {
                resolvedStorage = await ProwlRuntime.shared.currentStorage()
            }

            let existingLogs = await resolvedStorage.allLogs()
            if !existingLogs.isEmpty {
                let sorted = existingLogs.sorted { $0.startedAt > $1.startedAt }
                await Task { @MainActor [weak self] in
                    guard let self else { return }
                    await Task.yield()
                    self.logs = sorted
                }.value
            }
            
            let stream = await resolvedStorage.stream()

            for await entries in stream {
                guard !Task.isCancelled else { return }
                let sorted = entries.sorted { $0.startedAt > $1.startedAt }
                await Task { @MainActor [weak self] in
                    guard let self else { return }
                    await Task.yield()
                    self.logs = sorted
                }.value
            }
        }
    }

    deinit {
        streamTask?.cancel()
    }

    var filteredLogs: [NetworkLog] {
        logs.filter { log in
            matchesSearch(log) && statusFilter.matches(log.statusCode) && contentTypeFilter.matches(log)
        }
    }

    private func matchesSearch(_ log: NetworkLog) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        
        if (log.url?.absoluteString.lowercased() ?? "").contains(query) { return true }
        if log.method.lowercased().contains(query) { return true }
        if let code = log.statusCode, String(code).contains(query) { return true }
        
        if log.requestHeaders.values.contains(where: { $0.lowercased().contains(query) }) { return true }
        if log.responseHeaders.values.contains(where: { $0.lowercased().contains(query) }) { return true }
        
        if let resBody = log.responseBody, let text = String(data: resBody.data, encoding: .utf8), text.lowercased().contains(query) { return true }
        if let reqBody = log.requestBody, let text = String(data: reqBody.data, encoding: .utf8), text.lowercased().contains(query) { return true }
        
        return false
    }

    func clearLogs() {
        Task {
            let targetStorage: ProwlStorage
            if let explicitStorage = explicitStorage {
                targetStorage = explicitStorage
            } else {
                targetStorage = await ProwlRuntime.shared.currentStorage()
            }
            await targetStorage.clear()
            ProwlEndpointRateAlerts.resetCounters()
        }
    }
}

enum ProwlContentTypeCategory: String, CaseIterable, Identifiable {
    case all = "All Types"
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case image = "Image"
    case other = "Other"

    var id: String { rawValue }

    func matches(_ log: NetworkLog) -> Bool {
        guard self != .all else { return true }
        
        let headerType = log.responseHeaders.first(where: { $0.key.lowercased() == "content-type" })?.value
        let type = (log.responseBody?.contentType ?? headerType ?? "").lowercased()
        
        if type.isEmpty {
            return self == .other
        }
        
        switch self {
        case .json: return type.contains("json")
        case .xml: return type.contains("xml")
        case .html: return type.contains("html")
        case .image: return type.contains("image")
        case .other:
            let isKnown = type.contains("json") || type.contains("xml") || type.contains("html") || type.contains("image")
            return !isKnown
        case .all: return true
        }
    }
}
