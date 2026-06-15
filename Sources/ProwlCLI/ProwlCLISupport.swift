//
//  ProwlCLISupport.swift
//  ProwlCLI
//

import Foundation
import ProwlCore

enum ProwlCLIError: LocalizedError {
    case fileNotFound(String)
    case readFailed(String, Error)
    case writeFailed(String, Error)
    case emptySession
    case relayPortInvalid(Int)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .readFailed(path, error):
            return "Could not read \(path): \(error.localizedDescription)"
        case let .writeFailed(path, error):
            return "Could not write \(path): \(error.localizedDescription)"
        case .emptySession:
            return "Session file contains no network logs."
        case let .relayPortInvalid(port):
            return "Invalid relay port: \(port)"
        case let .installFailed(message):
            return message
        }
    }
}

enum ProwlCLISupport {
    static let defaultSessionPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/ProwlKit/prowl_session.json")
            .path
    }()

    static func resolveInputPath(_ path: String?) throws -> String {
        if let path, !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else {
                throw ProwlCLIError.fileNotFound(expanded)
            }
            return expanded
        }

        guard FileManager.default.fileExists(atPath: defaultSessionPath) else {
            throw ProwlCLIError.fileNotFound(defaultSessionPath)
        }
        return defaultSessionPath
    }

    static func loadSession(from path: String) throws -> [NetworkLog] {
        let logs = try loadSessionAllowEmpty(from: path)
        guard !logs.isEmpty else { throw ProwlCLIError.emptySession }
        return logs
    }

    static func loadSessionAllowEmpty(from path: String) throws -> [NetworkLog] {
        do {
            let json = try String(contentsOfFile: path, encoding: .utf8)
            return ProwlSessionCodec.fromJSON(json)
        } catch {
            throw ProwlCLIError.readFailed(path, error)
        }
    }

    static func writeOutput(_ text: String, to outputPath: String?) throws {
        if let outputPath, outputPath != "-" {
            let expanded = (outputPath as NSString).expandingTildeInPath
            do {
                try text.write(toFile: expanded, atomically: true, encoding: .utf8)
            } catch {
                throw ProwlCLIError.writeFailed(expanded, error)
            }
            return
        }

        print(text, terminator: text.hasSuffix("\n") ? "" : "\n")
    }

    static func filteredLogs(_ logs: [NetworkLog], filter: String?) -> [NetworkLog] {
        guard let filter, !filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return logs
        }
        let query = ProwlSearchParser.parse(filter)
        return logs.filter { ProwlSearchParser.matches($0, query: query) }
    }
}
