//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createBusinessCard(userId: Int64, title: String) async throws -> BusinessCard {
        let id = await ApplicationManager.shared.generateId()
        let businessCard = BusinessCard(id: id, userId: userId, title: title, color1: "#ffffff", color2: "#FF00FF", color3: "#000000")
        try await businessCard.save(on: self.db)
        
        return businessCard
    }
    
    func getBusinessCard(userId: Int64) async throws -> BusinessCard? {
        return try await BusinessCard.query(on: self.db)
            .with(\.$user)
            .with(\.$businessCardFields)
            .filter(\.$user.$id == userId)
            .first()
    }
}
