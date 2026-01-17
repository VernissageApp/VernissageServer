//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getHomeCard(title: String) async throws -> HomeCard? {
        return try await HomeCard.query(on: self.db).filter(\.$title == title).first()
    }
    
    func createHomeCard(title: String, body: String, order: Int) async throws -> HomeCard {
        let id = await ApplicationManager.shared.generateId()
        let homeCard = HomeCard(id: id,
                              title: title,
                              body: body,
                              order: order)
        _ = try await homeCard.save(on: self.db)
        return homeCard
    }
}
