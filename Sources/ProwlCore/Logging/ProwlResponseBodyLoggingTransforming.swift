//
//  ProwlResponseBodyLoggingTransforming.swift
//  Prowl
//
//  Created by Elmee on 19/05/26.
//  Copyright © 2026 Elmee. All rights reserved.
//
//

import Foundation

public protocol ProwlResponseBodyLoggingTransforming: AnyObject, Sendable {
    func responseBodyForLogging(
        data: Data,
        contentType: String?,
        url: URL?,
        statusCode: Int?
    ) -> Data?
}
