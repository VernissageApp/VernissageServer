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
    /// Retrieves follow information between two users.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user who is following.
    ///   - targetId: The Id of the user being followed.
    ///   - database: The database to perform the query on.
    /// - Returns: The ``Follow`` model if a follow relationship exists, otherwise `nil`.
    /// - Throws: An error if the database query fails.
    func get(sourceId: Int64, targetId: Int64, on database: Database) async throws -> Follow?
    
    /// Returns the count of accounts the specified user is following.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user whose following count is requested.
    ///   - database: The database to perform the query on.
    /// - Returns: The number of approved accounts the user is following.
    /// - Throws: An error if the database query fails.
    func count(sourceId: Int64, on database: Database) async throws -> Int
    
    /// Retrieves a paginated list of users that the specified user is following.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user whose following list is requested.
    ///   - onlyApproved: Whether to include only approved relationships.
    ///   - page: The page number for pagination.
    ///   - size: The number of items per page.
    ///   - database: The database to perform the query on.
    /// - Returns: A paginated list (``Page<User>``) of users being followed.
    /// - Throws: An error if the database query fails.
    func following(sourceId: Int64, onlyApproved: Bool, page: Int, size: Int, on database: Database) async throws -> Page<User>
    
    /// Retrieves a linkable list of users that the specified user is following based on linkable parameters.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user whose following list is requested.
    ///   - onlyApproved: Whether to include only approved relationships.
    ///   - linkableParams: Parameters for linkable pagination and filtering.
    ///   - context: The execution context containing the database.
    /// - Returns: A ``LinkableResult<User>`` containing the users being followed.
    /// - Throws: An error if the database query fails.
    func following(sourceId: Int64, onlyApproved: Bool, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>

    /// Returns the count of followers for the specified user.
    ///
    /// - Parameters:
    ///   - targetId: The Id of the user whose follower count is requested.
    ///   - database: The database to perform the query on.
    /// - Returns: The number of approved followers.
    /// - Throws: An error if the database query fails.
    func count(targetId: Int64, on database: Database) async throws -> Int
    
    /// Retrieves a paginated list of users who follow the specified user.
    ///
    /// - Parameters:
    ///   - targetId: The Id of the user whose followers list is requested.
    ///   - onlyApproved: Whether to include only approved relationships.
    ///   - page: The page number for pagination.
    ///   - size: The number of items per page.
    ///   - database: The database to perform the query on.
    /// - Returns: A paginated list (``Page<User>``) of followers.
    /// - Throws: An error if the database query fails.
    func follows(targetId: Int64, onlyApproved: Bool, page: Int, size: Int, on database: Database) async throws -> Page<User>
    
    /// Retrieves a linkable list of users who follow the specified user based on linkable parameters.
    ///
    /// - Parameters:
    ///   - targetId: The Id of the user whose followers list is requested.
    ///   - onlyApproved: Whether to include only approved relationships.
    ///   - linkableParams: Parameters for linkable pagination and filtering.
    ///   - context: The execution context containing the database.
    /// - Returns: A ``LinkableResult<User>`` containing the followers.
    /// - Throws: An error if the database query fails.
    func follows(targetId: Int64, onlyApproved: Bool, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User>
    
    /// Initiates a follow relationship from one user to another.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user who wants to follow another user.
    ///   - targetId: The Id of the user to be followed.
    ///   - approved: Whether the follow relationship is initially approved.
    ///   - activityId: An optional activity identifier related to the follow action.
    ///   - context: The execution context containing the database and services.
    /// - Returns: The Id of the created or existing follow relationship.
    /// - Throws: An error if the database operation fails.
    func follow(sourceId: Int64, targetId: Int64, approved: Bool, activityId: String?, on context: ExecutionContext) async throws -> Int64
    
    /// Removes a follow relationship from one user to another.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user who wants to unfollow another user.
    ///   - targetId: The Id of the user to be unfollowed.
    ///   - context: The execution context containing the database.
    /// - Returns: The Id of the deleted follow relationship if it existed, otherwise `nil`.
    /// - Throws: An error if the database operation fails.
    func unfollow(sourceId: Int64, targetId: Int64, on context: ExecutionContext) async throws -> Int64?
    
    /// Approves a pending follow relationship.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user who initiated the follow.
    ///   - targetId: The Id of the user who approves the follow.
    ///   - database: The database to perform the update on.
    /// - Throws: An error if the database operation fails.
    func approve(sourceId: Int64, targetId: Int64, on database: Database) async throws
    
    /// Rejects (deletes) a pending follow relationship.
    ///
    /// - Parameters:
    ///   - sourceId: The Id of the user who initiated the follow.
    ///   - targetId: The Id of the user who rejects the follow.
    ///   - database: The database to perform the deletion on.
    /// - Throws: An error if the database operation fails.
    func reject(sourceId: Int64, targetId: Int64, on database: Database) async throws
        
    /// Retrieves follow relationships that require approval by the specified user.
    ///
    /// - Parameters:
    ///   - userId: The Id of the user who needs to approve follow requests.
    ///   - linkableParams: Parameters for linkable pagination and filtering.
    ///   - context: The execution context containing the database.
    /// - Returns: A `LinkableResult<RelationshipDto>` containing follow relationships awaiting approval.
    /// - Throws: An error if the database query fails.
    func toApprove(userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<RelationshipDto>
}

/// A service for managing user follows.
final class FollowsService: FollowsServiceType {
    func get(sourceId: Int64, targetId: Int64, on database: Database) async throws -> Follow? {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return nil
        }
        
        return followFromDatabase
    }
    
    public func count(sourceId: Int64, on database: Database) async throws -> Int {
        return try await Follow.query(on: database).group(.and) { queryGroup in
            queryGroup.filter(\.$source.$id == sourceId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func following(sourceId: Int64, onlyApproved: Bool, page: Int, size: Int, on database: Database) async throws -> Page<User> {
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
    
    public func following(sourceId: Int64, onlyApproved: Bool, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User> {
        var queryBuilder = Follow.query(on: context.db)
            .with(\.$target) { target in
                target
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }

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
    
    public func count(targetId: Int64, on database: Database) async throws -> Int {
        return try await Follow.query(on: database).group(.and) { queryGroup in
            queryGroup.filter(\.$target.$id == targetId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func follows(targetId: Int64, onlyApproved: Bool, page: Int, size: Int, on database: Database) async throws -> Page<User> {
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
    
    public func follows(targetId: Int64, onlyApproved: Bool, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<User> {
        var queryBuilder = Follow.query(on: context.db)
            .with(\.$source) { source in
                source
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
        
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
    func follow(sourceId: Int64, targetId: Int64, approved: Bool, activityId: String?, on context: ExecutionContext) async throws -> Int64 {
        if let followFromDatabase = try await Follow.query(on: context.db)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() {
            return try followFromDatabase.requireID()
        }

        let id = context.services.snowflakeService.generate()
        let follow = Follow(id: id, sourceId: sourceId, targetId: targetId, approved: approved, activityId: activityId)
        try await follow.save(on: context.db)
        
        return try follow.requireID()
    }
    
    func unfollow(sourceId: Int64, targetId: Int64, on context: ExecutionContext) async throws -> Int64? {
        guard let follow = try await Follow.query(on: context.db)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return nil
        }
        
        try await follow.delete(on: context.db)
        
        return try follow.requireID()
    }
    
    func approve(sourceId: Int64, targetId: Int64, on database: Database) async throws {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return
        }

        followFromDatabase.approved = true
        try await followFromDatabase.save(on: database)
    }
    
    func reject(sourceId: Int64, targetId: Int64, on database: Database) async throws {
        guard let followFromDatabase = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return
        }

        try await followFromDatabase.delete(on: database)
    }
        
    func toApprove(userId: Int64, linkableParams: LinkableParams, on context: ExecutionContext) async throws -> LinkableResult<RelationshipDto> {
        var query = Follow.query(on: context.db)
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
        
        let relationshipsService = context.services.relationshipsService
        let relationships = try await relationshipsService.relationships(userId: userId, relatedUserIds: relatedUserIds, on: context.db)
        
        return LinkableResult(
            maxId: sortedFollowsToApprove.last?.stringId(),
            minId: sortedFollowsToApprove.first?.stringId(),
            data: relationships
        )
    }
}
