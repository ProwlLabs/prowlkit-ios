//
//  ProwlGrpcSwiftSupport.swift
//  ProwlGRPC
//

import Foundation
import GRPCCore

@available(gRPCSwift 2.0, *)
enum ProwlGrpcSwiftSupport {
    static func methodType(for descriptor: MethodDescriptor) -> String {
        if #available(gRPCSwift 2.3, *) {
            switch descriptor.type {
            case .unary:
                return "UNARY"
            case .clientStreaming:
                return "CLIENT_STREAMING"
            case .serverStreaming:
                return "SERVER_STREAMING"
            case .bidirectionalStreaming:
                return "BIDIRECTIONAL_STREAMING"
            case .none:
                break
            }
        }
        return "GRPC"
    }

    static func metadataHeaders(_ metadata: Metadata) -> [String: String] {
        var headers: [String: String] = [:]
        headers.reserveCapacity(metadata.count)

        for (key, value) in metadata {
            headers[key] = value.encoded()
        }

        return headers
    }

    static func grpcStatusCode(from error: RPCError) -> Int {
        error.code.rawValue
    }

    static func remotePeer(from context: ClientContext) -> String? {
        let peer = context.remotePeer.trimmingCharacters(in: .whitespacesAndNewlines)
        return peer.isEmpty ? nil : peer
    }
}
