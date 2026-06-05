//
//  ProwlMocksViewModel.swift
//  Prowl
//
//  Created by Elmee on 05/06/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

@MainActor
public final class ProwlMocksViewModel: ObservableObject {
    @Published public private(set) var rules: [ProwlMockRule] = []
    @Published public private(set) var isLoading = false

    public init() {}

    public func load() async {
        isLoading = true
        rules = await ProwlMocker.shared.allRules()
        isLoading = false
    }

    public func toggleEnabled(_ rule: ProwlMockRule) {
        Task {
            var updated = rule
            updated.isEnabled = !rule.isEnabled
            await ProwlMocker.shared.updateRule(updated)
            await load()
        }
    }

    public func delete(_ rule: ProwlMockRule) {
        Task {
            await ProwlMocker.shared.removeRule(id: rule.id)
            await load()
        }
    }

    public func deleteAll() {
        Task {
            await ProwlMocker.shared.removeAllRules()
            await load()
        }
    }
}
