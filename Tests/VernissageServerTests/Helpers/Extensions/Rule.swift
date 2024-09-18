//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createRule(order: Int, text: String) async throws -> Rule {
        let rule = Rule(order: order, text: text)
        _ = try await rule.save(on: self.db)
        return rule
    }
    
    func clearRules() async throws {
        let all = try await Rule.query(on: self.db).all()
        try await all.delete(on: self.db)
    }
    
    func getRule(id: Int64) async throws -> Rule? {
        return try await Rule.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getRule(text: String) async throws -> Rule? {
        return try await Rule.query(on: self.db)
            .filter(\.$text == text)
            .first()
    }
}
