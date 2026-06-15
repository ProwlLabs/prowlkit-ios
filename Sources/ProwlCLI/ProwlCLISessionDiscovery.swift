//
//  ProwlCLISessionDiscovery.swift
//  ProwlCLI
//

import Foundation
import ProwlCore

struct ProwlSessionSource: Identifiable, Sendable {
    enum Platform: String, Sendable {
        case macOS
        case iOSSimulator
    }

    let id: String
    let platform: Platform
    let label: String
    let path: String
    let modifiedAt: Date?
    let logCount: Int?
    let isBooted: Bool
}

enum ProwlCLISessionDiscovery {
    private static let sessionFileName = "prowl_session.json"
    private static let sessionSubpath = "Library/Application Support/ProwlKit/\(sessionFileName)"

    static func discoverAll() -> [ProwlSessionSource] {
        let booted = bootedSimulatorUDIDs()
        var sources: [ProwlSessionSource] = []
        if let mac = macOSSession() {
            sources.append(mac)
        }
        sources.append(contentsOf: simulatorSessions(booted: booted))
        return sources.sorted { lhs, rhs in
            if lhs.isBooted != rhs.isBooted { return lhs.isBooted && !rhs.isBooted }
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
    }

    static func bootedSimulatorUDIDs(timeout: TimeInterval = 5) -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "booted", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let group = DispatchGroup()
        group.enter()
        final class Termination: @unchecked Sendable {
            var status = Int32(-1)
        }
        let termination = Termination()
        process.terminationHandler = { proc in
            termination.status = proc.terminationStatus
            group.leave()
        }

        guard (try? process.run()) != nil else { return [] }
        guard group.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            return []
        }
        guard termination.status == 0,
              let data = try? pipe.fileHandleForReading.readToEnd(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            return []
        }

        var booted: Set<String> = []
        for runtimeDevices in devices.values {
            for device in runtimeDevices where (device["state"] as? String) == "Booted" {
                if let udid = device["udid"] as? String {
                    booted.insert(udid)
                }
            }
        }
        return booted
    }

    private static func macOSSession() -> ProwlSessionSource? {
        let path = ProwlCLISupport.defaultSessionPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let metadata = fileMetadata(path: path)
        return ProwlSessionSource(
            id: "macos",
            platform: .macOS,
            label: "This Mac",
            path: path,
            modifiedAt: metadata.modifiedAt,
            logCount: metadata.logCount,
            isBooted: true
        )
    }

    private static func simulatorSessions(booted: Set<String>) -> [ProwlSessionSource] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        guard let deviceIDs = try? FileManager.default.contentsOfDirectory(atPath: devicesRoot.path) else {
            return []
        }

        var sources: [ProwlSessionSource] = []

        for udid in deviceIDs where udid.count >= 8 {
            let deviceRoot = devicesRoot.appendingPathComponent(udid)
            let plistPath = deviceRoot.appendingPathComponent("device.plist")
            let deviceName = deviceName(from: plistPath) ?? String(udid.prefix(8)) + "…"
            let appContainers = deviceRoot
                .appendingPathComponent("data/Containers/Data/Application")

            guard let appIDs = try? FileManager.default.contentsOfDirectory(atPath: appContainers.path) else {
                continue
            }

            for appID in appIDs {
                let path = appContainers
                    .appendingPathComponent(appID)
                    .appendingPathComponent(sessionSubpath)
                    .path
                guard FileManager.default.fileExists(atPath: path) else { continue }
                let metadata = fileMetadata(path: path)
                sources.append(
                    ProwlSessionSource(
                        id: "sim-\(udid)-\(appID)",
                        platform: .iOSSimulator,
                        label: "\(deviceName) (Simulator)",
                        path: path,
                        modifiedAt: metadata.modifiedAt,
                        logCount: metadata.logCount,
                        isBooted: booted.contains(udid)
                    )
                )
            }
        }

        return sources
    }

    private static func deviceName(from plistURL: URL) -> String? {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let name = plist["name"] as? String else {
            return nil
        }
        return name
    }

    private static func fileMetadata(path: String) -> (modifiedAt: Date?, logCount: Int?) {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let modifiedAt = values?.contentModificationDate
        let logCount: Int?
        if let json = try? String(contentsOf: url, encoding: .utf8) {
            logCount = ProwlSessionCodec.fromJSON(json).count
        } else {
            logCount = nil
        }
        return (modifiedAt, logCount)
    }

    static func formatRelative(_ date: Date?) -> String {
        guard let date else { return "—" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }
}
