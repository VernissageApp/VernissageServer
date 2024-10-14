//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createFeaturedUser(user: User, featuredUser: User) async throws -> FeaturedUser {
        let id = await ApplicationManager.shared.generateId()
        let featuredUser = try FeaturedUser(id: id, featuredUserId: featuredUser.requireID(), userId: user.requireID())
        _ = try await featuredUser.save(on: self.db)
        return featuredUser
    }
    
    func createFeaturedUser(user: User, users: [User]) async throws -> [FeaturedUser] {
        var list: [FeaturedUser] = []
        for item in users {
            let id = await ApplicationManager.shared.generateId()
            let featuredUser = try FeaturedUser(id: id, featuredUserId: item.requireID(), userId: user.requireID())
            try await featuredUser.save(on: self.db)
            
            list.append(featuredUser)
        }
        
        return list
    }
    
    func getAllFeaturedUsers() async throws -> [FeaturedUser] {
        try await FeaturedUser.query(on: self.db)
            .with(\.$featuredUser)
            .sort(\.$createdAt, .descending)
            .all()
    }
}
