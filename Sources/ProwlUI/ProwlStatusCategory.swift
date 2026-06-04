//
//  ProwlStatusCategory.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

enum ProwlStatusCategory: String, CaseIterable, Identifiable, Sendable {
    case all
    case success2xx
    case clientError4xx
    case serverError5xx
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .success2xx: return "2xx"
        case .clientError4xx: return "4xx"
        case .serverError5xx: return "5xx"
        case .other: return "Other"
        }
    }

    func matches(_ statusCode: Int?) -> Bool {
        guard let statusCode else { return self == .all || self == .other }
        switch self {
        case .all:
            return true
        case .success2xx:
            return (200...299).contains(statusCode)
        case .clientError4xx:
            return (400...499).contains(statusCode)
        case .serverError5xx:
            return (500...599).contains(statusCode)
        case .other:
            return !(200...299).contains(statusCode)
                && !(400...499).contains(statusCode)
                && !(500...599).contains(statusCode)
        }
    }
}
