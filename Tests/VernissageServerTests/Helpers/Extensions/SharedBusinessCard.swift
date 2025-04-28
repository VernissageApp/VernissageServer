//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createSharedBusinessCard(businessCardId: Int64, title: String, thirdPartyName: String, revokedAt: Date? = nil) async throws -> SharedBusinessCard {
        let id = await ApplicationManager.shared.generateId()
        let code = String.createRandomString(length: 64)
        let businessCard = SharedBusinessCard(id: id,
                                              businessCardId: businessCardId,
                                              code: code,
                                              title: title,
                                              thirdPartyName: thirdPartyName)
        
        if let revokedAt {
            businessCard.revokedAt = revokedAt
        }
        
        try await businessCard.save(on: self.db)
        
        return businessCard
    }
    
    func getSharedBusinessCard(businessCardId: Int64) async throws -> [SharedBusinessCard] {
        return try await SharedBusinessCard.query(on: self.db)
            .with(\.$messages)
            .filter(\.$businessCard.$id == businessCardId)
            .all()
    }
}
