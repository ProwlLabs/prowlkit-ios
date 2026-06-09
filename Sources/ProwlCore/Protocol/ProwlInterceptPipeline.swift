//
//  ProwlInterceptPipeline.swift
//  Prowl
//
//  Chain of Responsibility: rewrite outgoing request, then optionally short-circuit with a mock.
//

import Foundation

/// Mutable state carried through the intercept chain.
package struct ProwlInterceptContext: Sendable {
    var effectiveRequest: URLRequest
    var requestBodyData: Data?
    let startedAt: Date
    var requestWasRewritten: Bool

    package init(
        effectiveRequest: URLRequest,
        requestBodyData: Data?,
        startedAt: Date,
        requestWasRewritten: Bool = false
    ) {
        self.effectiveRequest = effectiveRequest
        self.requestBodyData = requestBodyData
        self.startedAt = startedAt
        self.requestWasRewritten = requestWasRewritten
    }
}

/// Outcome after the intercept chain runs.
package enum ProwlInterceptResult: Sendable {
    /// Continue to the real network stack.
    case network(ProwlInterceptContext)
    /// Stop the chain and return a synthetic response.
    case mocked(ProwlInterceptContext, rule: ProwlMockRule)
}

/// Request intercept chain (rewrite → mock).
///
/// Ignore rules run earlier in ``ProwlProtocol/canInit(with:)``.
/// Logging, masking, and persistence run after the response in ``ProwlProtocol``.
package enum ProwlInterceptPipeline {
    package static func run(
        request: URLRequest,
        requestBodyData: Data?,
        startedAt: Date
    ) async -> ProwlInterceptResult {
        var context = ProwlInterceptContext(
            effectiveRequest: request,
            requestBodyData: requestBodyData,
            startedAt: startedAt
        )

        context = await applyRewrite(to: context)

        if let mockRule = await ProwlMocker.shared.findMatch(for: context.effectiveRequest) {
            return .mocked(context, rule: mockRule)
        }

        return .network(context)
    }

    private static func applyRewrite(to context: ProwlInterceptContext) async -> ProwlInterceptContext {
        guard let rule = await ProwlRequestRewriter.shared.findMatch(for: context.effectiveRequest) else {
            return context
        }

        var updated = context
        updated.effectiveRequest = await ProwlRequestRewriter.shared.apply(
            to: context.effectiveRequest,
            rule: rule
        )
        updated.requestWasRewritten = true
        updated.requestBodyData = ProwlProtocol.captureRequestBodyPreflight(from: updated.effectiveRequest)
            ?? context.requestBodyData
        return updated
    }
}
