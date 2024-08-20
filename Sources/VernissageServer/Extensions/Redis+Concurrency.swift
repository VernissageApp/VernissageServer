//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import NIOCore
import Vapor
import RediStack
import Foundation
import Redis

extension Application.Redis {
    public func set(key: String, value: String) async throws -> RESPValue {
        let argumantes: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]

        return try await send(command: "SET", with: argumantes)
    }
    
    public func get(key: String) async throws -> RESPValue {
        let argumantes = [RESPValue(from: key)]
        return try await send(command: "GET", with: argumantes)
    }
}
