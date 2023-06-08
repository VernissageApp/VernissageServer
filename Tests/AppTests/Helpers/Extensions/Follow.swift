//
//  File.swift
//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension Follow {
    static func create(sourceId: UInt64,
                       targetId: UInt64,
                       approved: Bool = true) async throws -> Follow {

        let follow = Follow(sourceId: sourceId, targetId: targetId, approved: approved)
        
        _ = try await follow.save(on: SharedApplication.application().db)

        return follow
    }
}
