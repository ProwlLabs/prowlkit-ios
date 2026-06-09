//
//  NetworkProtocol.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public enum NetworkProtocol: String, Codable, Sendable, Equatable {
    case http = "HTTP"
    case webSocket = "WEBSOCKET"
    case grpc = "GRPC"
}
