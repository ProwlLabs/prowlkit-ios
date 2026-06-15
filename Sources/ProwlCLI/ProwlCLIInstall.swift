//
//  ProwlCLIInstall.swift
//  ProwlCLI
//

import Foundation

enum ProwlCLIInstall {
    static func install(userLocal: Bool) throws -> String {
        let packageRoot = try locatePackageRoot()
        let binaryPath = try buildReleaseBinary(packageRoot: packageRoot)
        let destination = userLocal ? userLocalBinPath() : URL(fileURLWithPath: "/usr/local/bin/prowl")
        try installBinary(from: binaryPath, to: destination, userLocal: userLocal)
        return destination.path
    }

    private static func locatePackageRoot() throws -> URL {
        let env = ProcessInfo.processInfo.environment["PROWL_PACKAGE_ROOT"]
        if let env, !env.isEmpty {
            let url = URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }

        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw ProwlCLIError.installFailed("Run from the ProwlKit package root or set PROWL_PACKAGE_ROOT.")
    }

    private static func buildReleaseBinary(packageRoot: URL) throws -> URL {
        let process = Process()
        process.currentDirectoryURL = packageRoot
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["build", "-c", "release", "--product", "prowl"]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ProwlCLIError.installFailed(message?.isEmpty == false ? message! : "swift build failed.")
        }
        let binary = packageRoot.appendingPathComponent(".build/release/prowl")
        guard FileManager.default.fileExists(atPath: binary.path) else {
            throw ProwlCLIError.installFailed("Built binary not found at \(binary.path)")
        }
        return binary
    }

    private static func userLocalBinPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/bin/prowl")
    }

    private static func installBinary(from source: URL, to destination: URL, userLocal: Bool) throws {
        let fm = FileManager.default
        if userLocal {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["install", "-m", "755", source.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProwlCLIError.installFailed("sudo install failed. Try: prowl install --user")
        }
    }
}
