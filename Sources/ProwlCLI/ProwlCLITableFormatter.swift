//
//  ProwlCLITableFormatter.swift
//  ProwlCLI
//

import Foundation
import ProwlCore

enum ProwlCLITableFormatter {
    static func header(verbose: Bool) -> String {
        if verbose {
            return String(format: "%4@  %6@  %5@  %7@  %@", "#", "METHOD", "STATUS", "TIME", "URL")
        }
        return String(format: "%4@  %6@  %5@  %7@  %@", "#", "METHOD", "STATUS", "TIME", "HOST")
    }

    static func row(index: Int, log: NetworkLog, verbose: Bool) -> String {
        let status = log.statusCode.map(String.init) ?? "—"
        let duration = String(format: "%.0fms", log.duration * 1000)
        let target: String
        if verbose {
            target = log.url?.absoluteString ?? "—"
        } else {
            target = log.url?.host ?? "—"
        }
        return String(format: "%4d  %6@  %5@  %7@  %@", index, log.method, status, duration, target)
    }

    static func liveRow(index: Int, log: NetworkLog, compact: Bool) -> String {
        let status = log.statusCode.map(String.init) ?? "—"
        let duration = String(format: "%.0fms", log.duration * 1000)
        if compact {
            let url = log.url?.absoluteString ?? "—"
            return String(format: "%4d  %6@  %5@  %7@  %@", index, log.method, status, duration, url)
        }
        return row(index: index, log: log, verbose: true)
    }
}
