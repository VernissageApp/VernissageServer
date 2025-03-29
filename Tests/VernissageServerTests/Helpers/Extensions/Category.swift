//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func getCategory(name: String) async throws -> VernissageServer.Category? {
        return try await VernissageServer.Category.query(on: self.db)
            .with(\.$hashtags)
            .filter(\.$name == name)
            .first()
    }
    
    func setCategoryPriority(name: String, priority: Int) async throws {
        guard let category = try await self.getCategory(name: name) else {
            return
        }
        
        category.priority = priority
        try await category.save(on: self.db)
    }
    
    func setCategoryEnabled(name: String, enabled: Bool) async throws {
        guard let category = try await self.getCategory(name: name) else {
            return
        }
        
        category.isEnabled = enabled
        try await category.save(on: self.db)
    }
}
