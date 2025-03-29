//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func getStatusFavourite(statusId: Int64) async throws -> StatusFavourite? {
        return try await StatusFavourite.query(on: self.db)
            .filter(\.$status.$id == statusId)
            .first()
    }
    
    func createStatusFavourite(statusId: Int64, userId: Int64) async throws -> StatusFavourite {
        let id = await ApplicationManager.shared.generateId()
        let statusFavourite = StatusFavourite(id: id, statusId: statusId, userId: userId)
        try await statusFavourite.save(on: self.db)
        
        return statusFavourite
    }
    
    func createStatusFavourite(user: User, statuses: [Status]) async throws -> [StatusFavourite] {
        var userFavourites: [StatusFavourite] = []
        for status in statuses {
            let id = await ApplicationManager.shared.generateId()
            let statusFavourite = try StatusFavourite(id: id, statusId: status.requireID(), userId: user.requireID())
            try await statusFavourite.save(on: self.db)
            
            userFavourites.append(statusFavourite)
        }
        
        return userFavourites
    }
}
