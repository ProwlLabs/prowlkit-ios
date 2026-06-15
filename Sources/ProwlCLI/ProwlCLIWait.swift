//
//  ProwlCLIWait.swift
//  ProwlCLI
//

import Dispatch
import Foundation

enum ProwlCLIWait {
    /// Blocks until SIGINT or SIGTERM.
    static func untilInterrupted() {
        let semaphore = DispatchSemaphore(value: 0)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        source.setEventHandler { semaphore.signal() }
        source.resume()
        signal(SIGINT, SIG_IGN)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        termSource.setEventHandler { semaphore.signal() }
        termSource.resume()
        signal(SIGTERM, SIG_IGN)

        semaphore.wait()
    }
}
