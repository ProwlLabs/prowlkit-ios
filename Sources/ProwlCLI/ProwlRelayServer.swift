//
//  ProwlRelayServer.swift
//  ProwlCLI
//

import Foundation
import Network
import ProwlCore

final class ProwlRelayServer: @unchecked Sendable {
    private let port: UInt16
    private var listener: NWListener?
    private var onLog: ((NetworkLog) -> Void)?
    private let queue = DispatchQueue(label: "com.elmee.prowl.relay")

    init(port: UInt16 = UInt16(ProwlRelay.defaultPort)) {
        self.port = port
    }

    func start(onLog: @escaping (NetworkLog) -> Void) throws {
        self.onLog = onLog
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ProwlCLIError.relayPortInvalid(Int(port))
        }
        let params = NWParameters.tcp
        listener = try NWListener(using: params, on: nwPort)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            switch self.process(buffer, connection: connection) {
            case .handled:
                return
            case .needMore:
                if isComplete || error != nil {
                    connection.cancel()
                    return
                }
                self.receive(on: connection, accumulated: buffer)
            case .invalid:
                connection.cancel()
            }
        }
    }

    private enum ProcessResult {
        case handled
        case needMore
        case invalid
    }

    private func process(_ data: Data, connection: NWConnection) -> ProcessResult {
        guard let headerEnd = data.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) else {
            return data.count > 16_384 ? .invalid : .needMore
        }

        let headerData = data[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return .invalid }
        let headerLines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = headerLines.first else { return .invalid }
        let request = String(requestLine)

        if request.hasPrefix("GET /health") {
            respond(connection, status: 200, body: "{\"ok\":true}")
            return .handled
        }

        guard request.hasPrefix("POST /ingest") else {
            respond(connection, status: 404, body: "Not Found")
            return .handled
        }

        let contentLength = parseContentLength(headerText)
        let bodyStart = headerEnd.upperBound
        let bodyEnd = bodyStart + contentLength
        guard data.count >= bodyEnd else { return .needMore }

        let bodyData = data[bodyStart..<bodyEnd]
        guard let body = String(data: bodyData, encoding: .utf8) else {
            respond(connection, status: 400, body: "Bad Request")
            return .handled
        }

        let logs = ProwlSessionCodec.fromJSON(body)
        for log in logs {
            onLog?(log)
        }
        respond(connection, status: 204, body: "")
        return .handled
    }

    private func parseContentLength(_ headers: String) -> Int {
        for line in headers.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = lower.dropFirst("content-length:".count)
                    .trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private func respond(_ connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        default: statusText = "OK"
        }
        let bodyData = Data(body.utf8)
        let response =
            "HTTP/1.1 \(status) \(statusText)\r\n" +
            "Content-Length: \(bodyData.count)\r\n" +
            "Connection: close\r\n\r\n"
        var payload = Data(response.utf8)
        payload.append(bodyData)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
