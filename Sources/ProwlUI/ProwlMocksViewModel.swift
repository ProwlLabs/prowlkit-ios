//
//  ProwlMocksViewModel.swift
//  Prowl
//

import Foundation
import ProwlCore

@MainActor
public final class ProwlMocksViewModel: ObservableObject {
    @Published public private(set) var mockRules: [ProwlMockRule] = []
    @Published public private(set) var rewriteRules: [ProwlRequestRewriteRule] = []
    @Published public private(set) var isLoading = false

    public init() {}

    public func load() async {
        isLoading = true
        await reloadMocks()
        await reloadRewrites()
        isLoading = false
    }

    public func reloadMocks() async {
        mockRules = await ProwlMocker.shared.allRules()
    }

    public func reloadRewrites() async {
        rewriteRules = await ProwlRequestRewriter.shared.allRules()
    }

    public func toggleMockEnabled(_ rule: ProwlMockRule) {
        Task {
            var updated = rule
            updated.isEnabled = !rule.isEnabled
            await ProwlMocker.shared.saveRule(updated)
            await reloadMocks()
        }
    }

    public func toggleRewriteEnabled(_ rule: ProwlRequestRewriteRule) {
        Task {
            var updated = rule
            updated.isEnabled = !rule.isEnabled
            await ProwlRequestRewriter.shared.saveRule(updated)
            await reloadRewrites()
        }
    }

    public func deleteMock(_ rule: ProwlMockRule) {
        Task {
            await ProwlMocker.shared.removeRule(id: rule.id)
            await reloadMocks()
        }
    }

    public func deleteRewrite(_ rule: ProwlRequestRewriteRule) {
        Task {
            await ProwlRequestRewriter.shared.removeRule(id: rule.id)
            await reloadRewrites()
        }
    }

    public func deleteAllMocks() {
        Task {
            await ProwlMocker.shared.removeAllRules()
            await reloadMocks()
        }
    }

    public func deleteAllRewrites() {
        Task {
            await ProwlRequestRewriter.shared.removeAllRules()
            await reloadRewrites()
        }
    }

    public func moveMockUp(_ rule: ProwlMockRule) {
        Task {
            await ProwlMocker.shared.moveRuleUp(id: rule.id)
            await reloadMocks()
        }
    }

    public func moveMockDown(_ rule: ProwlMockRule) {
        Task {
            await ProwlMocker.shared.moveRuleDown(id: rule.id)
            await reloadMocks()
        }
    }
}
