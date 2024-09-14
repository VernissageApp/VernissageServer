//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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

@_documentation(visibility: private)
protocol FollowsServiceType: Sendable {
    /// Get follow information between two users.
    func get(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Follow?
    
    /// Returns amount of following accounts.
    func count(on database: Database, sourceId: Int64) async throws -> Int
    
    /// Returns list of following accoutns.
    func following(on database: Database, sourceId: Int64, onlyApproved: Bool, page: Int, size: Int) async throws -> Page<User>
    
    /// Returns list of following accoutns.
    func following(on request: Request, sourceId: Int64, onlyApproved: Bool, linkableParams: LinkableParams) async throws -> LinkableResult<User>

    /// Returns amount of followers.
    func count(on database: Database, targetId: Int64) async throws -> Int
    
    /// Returns list of account that follow account.
    func follows(on database: Database, targetId: Int64, onlyApproved: Bool, page: Int, size: Int) async throws -> Page<User>
    
    /// Returns list of account that follow account.
    func follows(on request: Request, targetId: Int64, onlyApproved: Bool, linkableParams: LinkableParams) async throws -> LinkableResult<User>
    
    /// Follow user.
    func follow(on database: Database, sourceId: Int64, targetId: Int64, approved: Bool, activityId: String?) async throws -> Int64
    
    /// Unfollow user.
    func unfollow(on database: Database, sourceId: Int64, targetId: Int64) async throws -> Int64?
    
    /// Approve relationship.
    func approve(on database: Database, sourceId: Int64, targetId: Int64) async throws
    
    /// Reject relationship.
    func reject(on database: Database, sourceId: Int64, targetId: Int64) async throws
        
    /// Relationships that have to be approved.
    func toApprove(on request: Request, userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<RelationshipDto>
}

/// A service for managing user follows.
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
    
    public func following(on database: Database, sourceId: Int64, onlyApproved: Bool, page: Int, size: Int) async throws -> Page<User> {
        let queryBuilder = User.query(on: database)
            .join(Follow.self, on: \User.$id == \Follow.$target.$id)
        
        if onlyApproved {
            queryBuilder
                .group(.and) { queryGroup in
                    queryGroup.filter(Follow.self, \.$source.$id == sourceId)
                    queryGroup.filter(Follow.self, \.$approved == true)
                }
        } else {
            queryBuilder
                .filter(Follow.self, \.$source.$id == sourceId)
        }
        
        return try await queryBuilder
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    public func following(on request: Request, sourceId: Int64, onlyApproved: Bool, linkableParams: LinkableParams) async throws -> LinkableResult<User> {
        var queryBuilder = Follow.query(on: request.db)
            .with(\.$target)
        
        if onlyApproved {
            queryBuilder
                .group(.and) { queryGroup in
                    queryGroup.filter(\.$source.$id == sourceId)
                    queryGroup.filter(\.$approved == true)
                }
        } else {
            queryBuilder
                .filter(\.$source.$id == sourceId)
        }
        
        if let minId = linkableParams.minId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            queryBuilder = queryBuilder
                .sort(\.$createdAt, .descending)
        }
        
        let follows = try await queryBuilder
            .limit(linkableParams.limit)
            .all()
        
        let sortedFollows = follows.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
                
        return LinkableResult(
            maxId: sortedFollows.last?.stringId(),
            minId: sortedFollows.first?.stringId(),
            data: sortedFollows.map({ $0.target })
        )
    }
    
    public func count(on database: Database, targetId: Int64) async throws -> Int {
        return try await Follow.query(on: database).group(.and) { queryGroup in
            queryGroup.filter(\.$target.$id == targetId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func follows(on database: Database, targetId: Int64, onlyApproved: Bool, page: Int, size: Int) async throws -> Page<User> {
        let queryBuilder = User.query(on: database)
            .join(Follow.self, on: \User.$id == \Follow.$source.$id)
        
        if onlyApproved {
            queryBuilder
                .group(.and) { queryGroup in
                    queryGroup.filter(Follow.self, \.$target.$id == targetId)
                    queryGroup.filter(Follow.self, \.$approved == true)
                }
        } else {
            queryBuilder
                .filter(Follow.self, \.$target.$id == targetId)
        }
        
        return try await queryBuilder
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    public func follows(on request: Request, targetId: Int64, onlyApproved: Bool, linkableParams: LinkableParams) async throws -> LinkableResult<User> {
        var queryBuilder = Follow.query(on: request.db)
            .with(\.$source)
        
        if onlyApproved {
            queryBuilder
                .group(.and) { queryGroup in
                    queryGroup.filter(\.$target.$id == targetId)
                    queryGroup.filter(\.$approved == true)
                }
        } else {
            queryBuilder
                .filter(\.$target.$id == targetId)
        }
        
        if let minId = linkableParams.minId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            queryBuilder = queryBuilder
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            queryBuilder = queryBuilder
                .sort(\.$createdAt, .descending)
        }
        
        let follows = try await queryBuilder
            .limit(linkableParams.limit)
            .all()
        
        let sortedFollows = follows.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
                
        return LinkableResult(
            maxId: sortedFollows.last?.stringId(),
            minId: sortedFollows.first?.stringId(),
            data: sortedFollows.map({ $0.source })
        )
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
        
    func toApprove(on request: Request, userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<RelationshipDto> {
        var query = Follow.query(on: request.db)
            .filter(\.$target.$id == userId)
            .filter(\.$approved == false)
            
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let followsToApprove = try await query
            .limit(linkableParams.limit)
            .all()
        
        let sortedFollowsToApprove = followsToApprove.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        let relatedUserIds = sortedFollowsToApprove.map({ $0.$source.id })
        
        let relationshipsService = request.application.services.relationshipsService
        let relationships = try await relationshipsService.relationships(on: request.db, userId: userId, relatedUserIds: relatedUserIds)
        
        return LinkableResult(
            maxId: sortedFollowsToApprove.last?.stringId(),
            minId: sortedFollowsToApprove.first?.stringId(),
            data: relationships
        )
    }
}
