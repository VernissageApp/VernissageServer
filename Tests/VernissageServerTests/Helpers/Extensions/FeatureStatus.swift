//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createFeaturedStatus(user: User, status: Status) async throws -> FeaturedStatus {
        let id = await ApplicationManager.shared.generateId()
        let featuredStatus = try FeaturedStatus(id: id, statusId: status.requireID(), userId: user.requireID())
        _ = try await featuredStatus.save(on: self.db)
        return featuredStatus
    }
    
    func createFeaturedStatus(user: User, statuses: [Status]) async throws -> [FeaturedStatus] {
        var featuredStatuses: [FeaturedStatus] = []
        for status in statuses {
            let id = await ApplicationManager.shared.generateId()
            let featuredStatus = try FeaturedStatus(id: id, statusId: status.requireID(), userId: user.requireID())
            try await featuredStatus.save(on: self.db)
            
            featuredStatuses.append(featuredStatus)
        }
        
        return featuredStatuses
    }
    
    func getAllFeaturedStatuses() async throws -> [FeaturedStatus] {
        try await FeaturedStatus.query(on: self.db)
            .with(\.$status)
            .sort(\.$createdAt, .descending)
            .all()
    }
}
