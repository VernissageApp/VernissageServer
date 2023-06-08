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
    func count(on request: Request, sourceId: UInt64) async throws -> Int
    
    /// Returns list of following accoutns.
    func following(on request: Request, sourceId: UInt64, page: Int, size: Int) async throws -> Page<User>

    /// Returns amount of followers.
    func count(on request: Request, targetId: UInt64) async throws -> Int
    
    /// Returns list of account that follow account.
    func follows(on request: Request, targetId: UInt64, page: Int, size: Int) async throws -> Page<User>
}

final class FollowsService: FollowsServiceType {

    public func count(on request: Request, sourceId: UInt64) async throws -> Int {
        return try await Follow.query(on: request.db).group(.and) { queryGroup in
            queryGroup.filter(\.$source.$id == sourceId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func following(on request: Request, sourceId: UInt64, page: Int, size: Int) async throws -> Page<User> {
        return try await User.query(on: request.db)
            .join(Follow.self, on: \User.$id == \Follow.$target.$id)
            .group(.and) { queryGroup in
                queryGroup.filter(Follow.self, \.$source.$id == sourceId)
                queryGroup.filter(Follow.self, \.$approved == true)
            }
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
    
    public func count(on request: Request, targetId: UInt64) async throws -> Int {
        return try await Follow.query(on: request.db).group(.and) { queryGroup in
            queryGroup.filter(\.$target.$id == targetId)
            queryGroup.filter(\.$approved == true)
        }.count()
    }
    
    public func follows(on request: Request, targetId: UInt64, page: Int, size: Int) async throws -> Page<User> {
        return try await User.query(on: request.db)
            .join(Follow.self, on: \User.$id == \Follow.$source.$id)
            .group(.and) { queryGroup in
                queryGroup.filter(Follow.self, \.$target.$id == targetId)
                queryGroup.filter(Follow.self, \.$approved == true)
            }
            .sort(Follow.self, \.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
    }
}
