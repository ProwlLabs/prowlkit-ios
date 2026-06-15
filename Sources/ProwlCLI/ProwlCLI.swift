//
//  ProwlCLI.swift
//  ProwlCLI
//

import ArgumentParser
import Foundation
import ProwlCore

@main
struct ProwlCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prowl",
        abstract: "Prowl network inspector — live relay, sessions, and export from the terminal.",
        discussion: """
        Terminal-first workflow:
          prowl install          # once
          prowl listen           # stream live traffic
          prowl sessions         # find macOS / Simulator session files
          prowl show             # inspect saved sessions

        Apps need ProwlKit embedded. Point them at the relay:
          Prowl.relayEndpoint = URL(string: "http://127.0.0.1:9284")!
        Or set environment variable PROWL_RELAY=1 in your Xcode scheme.
        """,
        subcommands: [
            Listen.self,
            Sessions.self,
            Devices.self,
            Watch.self,
            Doctor.self,
            Install.self,
            Export.self,
            Show.self,
            Redact.self,
        ],
        defaultSubcommand: Listen.self
    )
}

struct SessionInputOptions: ParsableArguments {
    @Argument(help: "Path to a Prowl session JSON file. Defaults to Application Support when omitted.")
    var sessionFile: String?

    func loadLogs(filter: String? = nil) throws -> [NetworkLog] {
        let path = try ProwlCLISupport.resolveInputPath(sessionFile)
        let logs = try ProwlCLISupport.loadSession(from: path)
        return ProwlCLISupport.filteredLogs(logs, filter: filter)
    }
}

extension ProwlCLI {
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export session logs to HAR, cURL, text, or JSON."
        )

        enum Format: String, ExpressibleByArgument, CaseIterable {
            case har
            case curl
            case text
            case json

            var exportFormat: ProwlExportFormat? {
                switch self {
                case .har: return .har
                case .curl: return .curlCommands
                case .text: return .formattedText
                case .json: return nil
                }
            }
        }

        @OptionGroup var input: SessionInputOptions

        @Option(name: .long, help: "Output format.")
        var format: Format = .har

        @Option(name: .shortAndLong, help: "Structured filter (method:GET status:4xx host:example.com).")
        var filter: String?

        @Option(name: .shortAndLong, help: "Output file path, or '-' for stdout.")
        var output: String = "-"

        mutating func run() throws {
            let logs = try input.loadLogs(filter: filter)
            let content: String
            if format == .json {
                content = ProwlSessionCodec.toJSON(logs)
            } else if let exportFormat = format.exportFormat {
                content = ProwlLogFormatter.export(logs: logs, as: exportFormat)
            } else {
                content = ""
            }
            try ProwlCLISupport.writeOutput(content, to: output)
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List captured requests in the terminal."
        )

        @OptionGroup var input: SessionInputOptions

        @Option(name: .shortAndLong, help: "Structured filter (method:GET status:4xx host:example.com).")
        var filter: String?

        @Flag(name: .long, help: "Include URL paths in the listing.")
        var verbose: Bool = false

        mutating func run() throws {
            let logs = try input.loadLogs(filter: filter)
            let lines = logs.enumerated().map { index, log in
                ProwlCLITableFormatter.row(index: index + 1, log: log, verbose: verbose)
            }
            let header = ProwlCLITableFormatter.header(verbose: verbose)
            let body = ([header] + lines).joined(separator: "\n")
            try ProwlCLISupport.writeOutput(body, to: "-")
        }
    }

    struct Redact: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Write a redacted copy of a session file."
        )

        @OptionGroup var input: SessionInputOptions

        @Option(name: .shortAndLong, help: "Output JSON path, or '-' for stdout.")
        var output: String = "-"

        @Option(name: .long, help: "Structured filter applied before redaction.")
        var filter: String?

        mutating func run() throws {
            let logs = try input.loadLogs(filter: filter)
            let redacted = ProwlSessionRedactor.redact(logs)
            try ProwlCLISupport.writeOutput(ProwlSessionCodec.toJSON(redacted), to: output)
        }
    }
}
