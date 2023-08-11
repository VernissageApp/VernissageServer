//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct FollowsServiceKey: StorageKey {
        typealias Value = FollowsServiceType
    }

    var followsService: FollowsServiceType {
        get {
            self.application.storage[FollowsServiceKey.self] ?? FollowsService()
        }
        nonmutating set {
            self.application.storage[FollowsServiceKey.self] = newValue
        }
    }
}

protocol FollowsServiceType {
    /// Get follow information between two users.
    func get(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Follow?
    
    /// Returns amount of following accounts.
    func count(on database: Database, sourceId: Int64) async throws -> Int
    
    /// Returns list of following accoutns.
    func following(on database: Database, sourceId: Int64, page: Int, size: Int) async throws -> Page<User>

    /// Returns amount of followers.
    func count(on database: Database, targetId: Int64) async throws -> Int
    
    /// Returns list of account that follow account.
    func follows(on database: Database, targetId: Int64, page: Int, size: Int) async throws -> Page<User>
    
    /// Follow user.
    func follow(on database: Database, sourceId: Int64, targetId: Int64, approved: Bool, activityId: String?) async throws -> Int64
    
    /// Unfollow user.
    func unfollow(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Int64?
    
    /// Approve relationship.
    func approve(on database: Database, sourceId: Int64, targetId: Int64) async throws
    
    /// Reject relationship.
    func reject(on database: Database, sourceId: Int64, targetId: Int64) async throws
    
    /// Get relationships between user and collection of other users.
    func relationships(on database: Database, userId: Int64, relatedUserIds: [Int64]) async throws -> [RelationshipDto]
    
    /// Relationships that have to be approved.
    func toApprove(on database: Database, userId: Int64, page: Int, size: Int) async throws -> [RelationshipDto]
}

final class FollowsService: FollowsServiceType {

    func get(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Follow? {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return nil
        }
        
        return followFromDatabase
    }
    
    public func count(on database: Database, sourceId: Int64) async throws -> Int {
        return try await Follow.query(on: database).group(.and) { queryGroup in
            queryGroup.filter(\.$source.$id == sourceId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func following(on database: Database, sourceId: Int64, page: Int, size: Int) async throws -> Page<User> {
        return try await User.query(on: database)
            .join(Follow.self, on: \User.$id == \Follow.$target.$id)
            .group(.and) { queryGroup in
                queryGroup.filter(Follow.self, \.$source.$id == sourceId)
                queryGroup.filter(Follow.self, \.$approved == true)
            }
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    public func count(on database: Database, targetId: Int64) async throws -> Int {
        return try await Follow.query(on: database).group(.and) { queryGroup in
            queryGroup.filter(\.$target.$id == targetId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func follows(on database: Database, targetId: Int64, page: Int, size: Int) async throws -> Page<User> {
        return try await User.query(on: database)
            .join(Follow.self, on: \User.$id == \Follow.$source.$id)
            .group(.and) { queryGroup in
                queryGroup.filter(Follow.self, \.$target.$id == targetId)
                queryGroup.filter(Follow.self, \.$approved == true)
            }
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    /// At the start following is always not approved (application is waiting from information from remote server).
    /// After information from remote server (approve/reject, done automatically or manually by the user) relationship is approved.
    func follow(on database: Database, sourceId: Int64, targetId: Int64, approved: Bool, activityId: String?) async throws -> Int64 {
        if let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() {
            return try followFromDatabase.requireID()
        }

        let follow = Follow(sourceId: sourceId, targetId: targetId, approved: approved, activityId: activityId)
        try await follow.save(on: database)
        
        return try follow.requireID()
    }
    
    func unfollow(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Int64? {
        guard let follow = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return nil
        }
        
        try await follow.delete(on: database)
        
        return try follow.requireID()
    }
    
    func approve(on database: Database, sourceId: Int64, targetId: Int64) async throws {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return
        }

        followFromDatabase.approved = true
        try await followFromDatabase.save(on: database)
    }
    
    func reject(on database: Database, sourceId: Int64, targetId: Int64) async throws {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return
        }

        try await followFromDatabase.delete(on: database)
    }
    
    func relationships(on database: Database, userId: Int64, relatedUserIds: [Int64]) async throws -> [RelationshipDto] {
        // Download from database all follows with specified user ids.
        let follows = try await Follow.query(on: database).group(.or) { group in
            group
                .filter(\.$source.$id ~~ relatedUserIds)
                .filter(\.$target.$id ~~ relatedUserIds)
        }.all()
        
        // Build array with relations.
        var relationships: [RelationshipDto] = []
        for relatedUserId in relatedUserIds {
            let following = follows.contains(where: { $0.$source.id == userId && $0.$target.id == relatedUserId && $0.approved == true })
            let followedBy = follows.contains(where: { $0.$source.id == relatedUserId && $0.$target.id == userId && $0.approved == true  })
            let requested = follows.contains(where: { $0.$source.id == userId && $0.$target.id == relatedUserId && $0.approved == false })
            let requestedBy = follows.contains(where: { $0.$source.id == relatedUserId && $0.$target.id == userId && $0.approved == false })
            
            relationships.append(RelationshipDto(userId: "\(relatedUserId)", following: following, followedBy: followedBy, requested: requested, requestedBy: requestedBy))
        }
        
        return relationships
    }
    
    func toApprove(on database: Database, userId: Int64, page: Int, size: Int) async throws -> [RelationshipDto] {
        let followsToApprove = try await Follow.query(on: database)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == false)
            .offset(page * size)
            .limit(size)
            .all()
        
        var relatedUserIds = followsToApprove.map({ $0.$source.id })
        return try await self.relationships(on: database, userId: userId, relatedUserIds: relatedUserIds)
    }
}
