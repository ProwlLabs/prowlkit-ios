//
//  ProwlWebSocketLogger.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public enum ProwlWebSocketEvent: Sendable {
    case open
    case message(text: String)
    case messageBinary(Data)
    case closing(code: Int, reason: String)
    case closed(code: Int, reason: String)
    case failure(String)
}

public enum ProwlWebSocketLogger {
    public static func log(
        connectionID: UUID = UUID(),
        url: URL?,
        event: ProwlWebSocketEvent,
        startedAt: Date = Date()
    ) async {
        let (method, statusCode, body, errorDescription): (String, Int?, NetworkLog.Body?, String?) = switch event {
        case .open:
            ("WS_OPEN", 101, nil, nil)
        case let .message(text):
            ("WS_MESSAGE", 200, NetworkLog.Body(data: Data(text.utf8), contentType: "text/plain"), nil)
        case let .messageBinary(data):
            ("WS_MESSAGE", 200, NetworkLog.Body(
                data: Data(ProwlBodyDecoder.hexPreview(data, maxBytes: 256).utf8),
                contentType: "application/octet-stream"
            ), nil)
        case let .closing(code, reason):
            ("WS_CLOSING", code, NetworkLog.Body(data: Data(reason.utf8), contentType: "text/plain"), nil)
        case let .closed(code, reason):
            ("WS_CLOSED", code, NetworkLog.Body(data: Data(reason.utf8), contentType: "text/plain"), nil)
        case let .failure(message):
            ("WS_FAILURE", nil, nil, message)
        }

        let log = NetworkLog(
            requestID: connectionID,
            url: url,
            method: method,
            responseBody: body,
            statusCode: statusCode,
            startedAt: startedAt,
            duration: 0,
            errorDescription: errorDescription,
            networkProtocol: .webSocket
        )

        let storage = await ProwlRuntime.shared.currentStorage()
        await storage.append(log)
    }
}

#if canImport(Foundation)
import Foundation

@available(iOS 13.0, macOS 10.15, *)
public final class ProwlWebSocketMonitor: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let connectionID = UUID()
    private let url: URL?
    private let startedAt = Date()
    private var task: URLSessionWebSocketTask?

    public init(url: URL?) {
        self.url = url
    }

    public func attach(to task: URLSessionWebSocketTask) {
        self.task = task
        task.delegate = self
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { await ProwlWebSocketLogger.log(connectionID: connectionID, url: url, event: .open, startedAt: startedAt) }
        receiveNext(from: webSocketTask)
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        Task {
            await ProwlWebSocketLogger.log(
                connectionID: connectionID,
                url: url,
                event: .closed(code: Int(closeCode.rawValue), reason: reasonText),
                startedAt: startedAt
            )
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        Task {
            await ProwlWebSocketLogger.log(
                connectionID: connectionID,
                url: url,
                event: .failure(error.localizedDescription),
                startedAt: startedAt
            )
        }
    }

    public func logIncomingMessage(_ message: URLSessionWebSocketTask.Message) {
        Task {
            switch message {
            case let .string(text):
                await ProwlWebSocketLogger.log(connectionID: connectionID, url: url, event: .message(text: text), startedAt: startedAt)
            case let .data(data):
                await ProwlWebSocketLogger.log(connectionID: connectionID, url: url, event: .messageBinary(data), startedAt: startedAt)
            @unknown default:
                break
            }
        }
    }

    private func receiveNext(from task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(message):
                self.logIncomingMessage(message)
                self.receiveNext(from: task)
            case .failure:
                break
            }
        }
    }
}
#endif
