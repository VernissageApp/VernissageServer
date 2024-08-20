//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct RelationshipsServiceKey: StorageKey {
        typealias Value = RelationshipsServiceType
    }

    var relationshipsService: RelationshipsServiceType {
        get {
            self.application.storage[RelationshipsServiceKey.self] ?? RelationshipsService()
        }
        nonmutating set {
            self.application.storage[RelationshipsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol RelationshipsServiceType {
    func relationships(on database: Database, userId: Int64, relatedUserIds: [Int64]) async throws -> [RelationshipDto]
}

/// A service for managing relationships in the system.
final class RelationshipsService: RelationshipsServiceType {

    func relationships(on database: Database, userId: Int64, relatedUserIds: [Int64]) async throws -> [RelationshipDto] {
        // Download from database all follows with specified user ids.
        let follows = try await Follow.query(on: database).group(.or) { group in
            group
                .filter(\.$source.$id ~~ relatedUserIds)
                .filter(\.$target.$id ~~ relatedUserIds)
        }.all()
        
        let userMutes = try await UserMute.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id ~~ relatedUserIds)
            .group(.or) { group in
                group
                    .filter(\.$muteEnd == nil)
                    .filter(\.$muteEnd > Date())
            }
            .all()
        
        // Build array with relations.
        var relationships: [RelationshipDto] = []
        for relatedUserId in relatedUserIds {
            let following = follows.contains(where: { $0.$source.id == userId && $0.$target.id == relatedUserId && $0.approved == true })
            let followedBy = follows.contains(where: { $0.$source.id == relatedUserId && $0.$target.id == userId && $0.approved == true  })
            let requested = follows.contains(where: { $0.$source.id == userId && $0.$target.id == relatedUserId && $0.approved == false })
            let requestedBy = follows.contains(where: { $0.$source.id == relatedUserId && $0.$target.id == userId && $0.approved == false })
            let userMute = userMutes.first(where: { $0.$mutedUser.id == relatedUserId })
            
            relationships.append(
                RelationshipDto(
                    userId: "\(relatedUserId)",
                    following: following,
                    followedBy: followedBy,
                    requested: requested,
                    requestedBy: requestedBy,
                    mutedStatuses: userMute?.muteStatuses ?? false,
                    mutedReblogs: userMute?.muteReblogs ?? false,
                    mutedNotifications: userMute?.muteNotifications ?? false
                )
            )
        }
        
        return relationships
    }
}
