//
//  ProwlRelay.swift
//  ProwlCore
//

import Foundation

/// Streams captured logs to a Prowl CLI relay (`prowl listen`) on the host machine.
public enum ProwlRelay {
    public static let defaultPort = 9_284

    /// When set, each appended log is POSTed to `{endpoint}/ingest`.
    nonisolated(unsafe) public static var endpoint: URL?

    /// Enables relay at ``defaultEndpoint`` (http://127.0.0.1:9284).
    public static var defaultEndpoint: URL {
        URL(string: "http://127.0.0.1:\(defaultPort)")!
    }

    package static func send(_ log: NetworkLog) {
        guard let endpoint else { return }
        let url = endpoint.appendingPathComponent("ingest")
        let payload = ProwlSessionCodec.toJSON([log])
        guard let body = payload.data(using: .utf8) else { return }

        Task.detached(priority: .utility) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    package static func applyEnvironmentDefaults() {
        guard endpoint == nil else { return }
        if let urlString = ProcessInfo.processInfo.environment["PROWL_RELAY_URL"],
           let url = URL(string: urlString) {
            endpoint = url
            return
        }
        if ProcessInfo.processInfo.environment["PROWL_RELAY"] == "1" {
            endpoint = defaultEndpoint
        }
    }
}
