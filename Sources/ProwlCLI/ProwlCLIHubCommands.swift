//
//  ProwlCLIHubCommands.swift
//  ProwlCLI
//

import ArgumentParser
import Darwin
import Foundation
import ProwlCore

extension ProwlCLI {
    struct Listen: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start the Prowl relay and stream live traffic in the terminal."
        )

        @Option(name: .long, help: "TCP port for the relay (default 9284).")
        var port: Int = ProwlRelay.defaultPort

        @Flag(name: .long, help: "Include full URLs in live output.")
        var verbose: Bool = false

        mutating func run() throws {
            guard port > 0, port <= 65_535 else {
                throw ProwlCLIError.relayPortInvalid(port)
            }

            let compactMode = !verbose
            let server = ProwlRelayServer(port: UInt16(port))
            var count = 0
            try server.start { log in
                count += 1
                let line = ProwlCLITableFormatter.liveRow(index: count, log: log, compact: compactMode)
                print(line)
                fflush(stdout)
            }

            let relayURL = URL(string: "http://127.0.0.1:\(port)")!
            print("Prowl relay listening on \(relayURL.absoluteString)")
            print("Apps with ProwlKit: set Prowl.relayEndpoint or PROWL_RELAY=1 in DEBUG")
            print("Press Ctrl+C to stop.\n")

            ProwlCLIWait.untilInterrupted()
            server.stop()
        }
    }

    struct Sessions: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List Prowl session files on this Mac (macOS apps and iOS Simulators)."
        )

        mutating func run() throws {
            let sources = ProwlCLISessionDiscovery.discoverAll()
            if sources.isEmpty {
                print("No Prowl session files found.")
                print("Enable persistence in your app: Prowl.isSessionPersistenceEnabled = true")
                print("Or run `prowl listen` and set Prowl.relayEndpoint for live streaming.")
                return
            }

            let header = String(format: "%-6@  %-6@  %-5@  %-8@  %@", "STATE", "LOGS", "AGE", "PLATFORM", "SOURCE")
            print(header)
            for source in sources {
                let state = source.isBooted ? "active" : "idle"
                let logs = source.logCount.map(String.init) ?? "—"
                let age = ProwlCLISessionDiscovery.formatRelative(source.modifiedAt)
                print(String(format: "%-6@  %-6@  %-5@  %-8@  %@", state, logs, age, source.platform.rawValue, source.label))
                print("       \(source.path)")
            }
        }
    }

    struct Devices: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show booted iOS Simulators and local macOS session status."
        )

        mutating func run() throws {
            let booted = ProwlCLISessionDiscovery.bootedSimulatorUDIDs()
            let sources = ProwlCLISessionDiscovery.discoverAll()

            print("Booted simulators: \(booted.count)")
            if booted.isEmpty {
                print("  (none — open Simulator or run an iOS app in Xcode)")
            }

            let macSession = sources.first { $0.platform == .macOS }
            if let macSession {
                let logs = macSession.logCount.map { "\($0) logs" } ?? "session present"
                print("macOS: \(logs) (\(ProwlCLISessionDiscovery.formatRelative(macSession.modifiedAt)))")
            } else {
                print("macOS: no session file yet")
            }

            let simSources = sources.filter { $0.platform == .iOSSimulator && $0.isBooted }
            if simSources.isEmpty {
                print("iOS Simulator sessions: none on booted devices")
            } else {
                print("iOS Simulator sessions:")
                for source in simSources {
                    let logs = source.logCount.map(String.init) ?? "—"
                    print("  • \(source.label): \(logs) requests")
                }
            }

            print("\nTip: run `prowl listen` then launch your app for live traffic.")
        }
    }

    struct Watch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Tail new requests from a session file (polls every second)."
        )

        @Argument(help: "Session JSON path. Defaults to the newest discovered session.")
        var sessionFile: String?

        mutating func run() throws {
            let path = try resolveWatchPath(sessionFile)
            var seen = Set(ProwlCLISessionCodec.loadIDs(from: path))
            print("Watching \(path) — Ctrl+C to stop.\n")

            final class WatchState: @unchecked Sendable {
                var stopped = false
            }
            let state = WatchState()
            let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
            source.setEventHandler { state.stopped = true }
            source.resume()
            signal(SIGINT, SIG_IGN)

            while !state.stopped {
                let logs = (try? ProwlCLISupport.loadSessionAllowEmpty(from: path)) ?? []
                for log in logs where !seen.contains(log.id) {
                    seen.insert(log.id)
                    print(ProwlCLITableFormatter.liveRow(index: seen.count, log: log, compact: true))
                    fflush(stdout)
                }
                Thread.sleep(forTimeInterval: 1)
            }
        }

        private func resolveWatchPath(_ path: String?) throws -> String {
            if let path, !path.isEmpty {
                return try ProwlCLISupport.resolveInputPath(path)
            }
            if let newest = ProwlCLISessionDiscovery.discoverAll().first {
                return newest.path
            }
            throw ProwlCLIError.fileNotFound(ProwlCLISupport.defaultSessionPath)
        }
    }

    struct Doctor: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify Prowl CLI, relay port, and session discovery."
        )

        mutating func run() throws {
            var ok = true

            if FileManager.default.isExecutableFile(atPath: ProcessInfo.processInfo.arguments[0]) {
                print("✓ prowl binary: \(ProcessInfo.processInfo.arguments[0])")
            } else {
                print("✓ prowl running")
            }

            let port = ProwlRelay.defaultPort
            if isPortAvailable(port) {
                print("✓ relay port \(port): available (run `prowl listen`)")
            } else if relayHealthCheck(port: port) {
                print("✓ relay port \(port): relay already running")
            } else {
                print("✗ relay port \(port): in use by another process")
                ok = false
            }

            let sessions = ProwlCLISessionDiscovery.discoverAll()
            print("✓ sessions found: \(sessions.count)")
            for source in sessions.prefix(3) {
                print("    • \(source.label)")
            }

            let booted = ProwlCLISessionDiscovery.bootedSimulatorUDIDs().count
            print("✓ booted simulators: \(booted)")

            if !ok {
                throw ExitCode.failure
            }
        }

        private func isPortAvailable(_ port: Int) -> Bool {
            let socket = socket(AF_INET, SOCK_STREAM, 0)
            guard socket >= 0 else { return false }
            defer { close(socket) }
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            return bound == 0
        }

        private func relayHealthCheck(port: Int) -> Bool {
            guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
            let semaphore = DispatchSemaphore(value: 0)
            final class HealthResult: @unchecked Sendable {
                var healthy = false
            }
            let result = HealthResult()
            let task = URLSession.shared.dataTask(with: url) { data, response, _ in
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let data, String(data: data, encoding: .utf8)?.contains("ok") == true {
                    result.healthy = true
                }
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 2)
            return result.healthy
        }
    }

    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build and install the prowl binary to PATH."
        )

        @Flag(name: .long, help: "Install to ~/.local/bin (no sudo).")
        var user: Bool = false

        mutating func run() throws {
            let path = try ProwlCLIInstall.install(userLocal: user)
            print("Installed prowl → \(path)")
            if user {
                let binDir = (path as NSString).deletingLastPathComponent
                print("Ensure \(binDir) is on your PATH.")
            }
            print("\nNext steps:")
            print("  1. prowl listen")
            print("  2. In your app (DEBUG): Prowl.relayEndpoint = URL(string: \"http://127.0.0.1:9284\")!")
            print("  3. Run the app — traffic appears in the terminal")
        }
    }
}

private enum ProwlCLISessionCodec {
    static func loadIDs(from path: String) -> [UUID] {
        guard let json = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return ProwlSessionCodec.fromJSON(json).map(\.id)
    }
}
