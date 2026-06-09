//
//  ProwlMetricsSessionDelegate.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

final class ProwlMetricsSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [Int: (Data?, URLResponse?, Error?) -> Void] = [:]
    private var dataBuffers: [Int: Data] = [:]
    weak var forwardingDelegate: URLSessionDelegate?

    func registerHandler(for task: URLSessionDataTask, handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        lock.prowlWithLock {
            handlers[task.taskIdentifier] = handler
            dataBuffers[task.taskIdentifier] = Data()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        ProwlTimingStore.store(metrics, forTaskID: task.taskIdentifier)
        forward { delegate in
            (delegate as? URLSessionTaskDelegate)?
                .urlSession?(session, task: task, didFinishCollecting: metrics)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.prowlWithLock {
            dataBuffers[dataTask.taskIdentifier, default: Data()].append(data)
        }
        forward { delegate in
            (delegate as? URLSessionDataDelegate)?
                .urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let delegate = forwardingDelegate as? URLSessionDataDelegate,
           delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))) {
            delegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var handler: ((Data?, URLResponse?, Error?) -> Void)?
        var data = Data()
        lock.prowlWithLock {
            handler = handlers.removeValue(forKey: task.taskIdentifier)
            data = dataBuffers.removeValue(forKey: task.taskIdentifier) ?? Data()
        }
        handler?(data, task.response, error)
        forward { delegate in
            (delegate as? URLSessionTaskDelegate)?
                .urlSession?(session, task: task, didCompleteWithError: error)
        }
    }

    private func forward(_ block: (URLSessionDelegate) -> Void) {
        guard let forwardingDelegate else { return }
        block(forwardingDelegate)
    }
}
