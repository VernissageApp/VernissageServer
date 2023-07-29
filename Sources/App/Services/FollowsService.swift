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
    /// Returns amount of following accounts.
    func count(on database: Database, sourceId: Int64) async throws -> Int
    
    /// Returns list of following accoutns.
    func following(on database: Database, sourceId: Int64, page: Int, size: Int) async throws -> Page<User>

    /// Returns amount of followers.
    func count(on database: Database, targetId: Int64) async throws -> Int
    
    /// Returns list of account that follow account.
    func follows(on database: Database, targetId: Int64, page: Int, size: Int) async throws -> Page<User>
    
    /// Follow user.
    func follow(on database: Database, sourceId: Int64, targetId: Int64, approved: Bool) async throws
    
    /// Unfollow user.
    func unfollow(on database: Database, sourceId: Int64, targetId: Int64) async throws
}

final class FollowsService: FollowsServiceType {

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
    
    func follow(on database: Database, sourceId: Int64, targetId: Int64, approved: Bool) async throws {
        if try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() != nil {
            return
        }
        
        let follow = Follow(sourceId: sourceId, targetId: targetId, approved: approved)
        try await follow.save(on: database)
    }
    
    func unfollow(on database: Database, sourceId: Int64, targetId: Int64) async throws {
        guard let follow = try await Follow.query(on: database)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first() else {
            return
        }
        
        try await follow.delete(on: database)
    }
}
