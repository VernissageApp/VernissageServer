//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Rule {
    static func create(order: Int, text: String) async throws -> Rule {
        let rule = Rule(order: order, text: text)
        _ = try await rule.save(on: SharedApplication.application().db)
        return rule
    }
    
    static func clear() async throws {
        let all = try await Rule.query(on: SharedApplication.application().db).all()
        try await all.delete(on: SharedApplication.application().db)
    }
    
    static func get(id: Int64) async throws -> Rule? {
        return try await Rule.query(on: SharedApplication.application().db)
            .filter(\.$id == id)
            .first()
    }
    
    static func get(text: String) async throws -> Rule? {
        return try await Rule.query(on: SharedApplication.application().db)
            .filter(\.$text == text)
            .first()
    }
}
