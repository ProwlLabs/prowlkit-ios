//
//  ProwlCLIInstall.swift
//  ProwlCLI
//

import Foundation

enum ProwlCLIInstall {
    private static let repo = "ProwlKit/prowlkit-ios"

    static func install(userLocal: Bool, fromSource: Bool, version: String?) throws -> String {
        let destination = userLocal ? userLocalBinPath() : URL(fileURLWithPath: "/usr/local/bin/prowl")

        if fromSource {
            let packageRoot = try locatePackageRoot()
            let binaryPath = try buildReleaseBinary(packageRoot: packageRoot)
            try installBinary(from: binaryPath, to: destination, userLocal: userLocal)
            return destination.path
        }

        if let binary = try? downloadReleaseBinary(to: destination, version: version) {
            return binary
        }

        if let packageRoot = try? locatePackageRoot() {
            let binaryPath = try buildReleaseBinary(packageRoot: packageRoot)
            try installBinary(from: binaryPath, to: destination, userLocal: userLocal)
            return destination.path
        }

        throw ProwlCLIError.installFailed(
            """
            Could not download a release binary and no local Package.swift was found.
            Install via Homebrew or the install script:
              brew install ProwlKit/prowlkit-ios/prowl
              curl -fsSL https://raw.githubusercontent.com/\(repo)/main/Scripts/install.sh | bash
            """
        )
    }

    private static func downloadReleaseBinary(to destination: URL, version: String?) throws -> String {
        let tag = try version ?? fetchLatestReleaseTag()
        let arch = currentArchitectureSuffix()
        let assetName = "prowl-macos-\(arch)"
        let url = URL(string: "https://github.com/\(repo)/releases/download/\(tag)/\(assetName)")!

        let semaphore = DispatchSemaphore(value: 0)
        final class DownloadResult: @unchecked Sendable {
            var data: Data?
            var error: Error?
        }
        let result = DownloadResult()

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result.error = error
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data, !data.isEmpty else {
                result.error = ProwlCLIError.installFailed("Release asset not found: \(assetName) (\(tag))")
                return
            }
            result.data = data
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 120)

        guard let data = result.data else {
            throw result.error ?? ProwlCLIError.installFailed("Download timed out.")
        }

        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try data.write(to: destination)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        return destination.path
    }

    private static func fetchLatestReleaseTag() throws -> String {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        let semaphore = DispatchSemaphore(value: 0)
        final class TagResult: @unchecked Sendable {
            var tag: String?
            var error: Error?
        }
        let result = TagResult()

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result.error = error
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                result.error = ProwlCLIError.installFailed("Could not resolve latest release.")
                return
            }
            result.tag = tag
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 30)

        guard let tag = result.tag else {
            throw result.error ?? ProwlCLIError.installFailed("Could not resolve latest release.")
        }
        return tag
    }

    private static func currentArchitectureSuffix() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
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
