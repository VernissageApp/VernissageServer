//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import JWT

/// Data stored in the JWT token.
struct UserPayload: JWTPayload, Authenticatable {    
    var id: String
    var userName: String
    var email: String?
    var name: String?
    var exp: Date
    var avatarUrl: String?
    var headerUrl: String?
    var roles: [String]
    var scopes: [String]?
    var application: String

    func verify(using algorithm: some JWTKit.JWTAlgorithm) async throws {
        // nothing to verify
    }
}

extension UserPayload {
    func isAdministrator() -> Bool {
        return roles.contains(Role.administrator)
    }
    
    func isModerator() -> Bool {
        return roles.contains(Role.moderator)
    }
    
    func isMember() -> Bool {
        return roles.contains(Role.member)
    }
}

extension UserPayload {
    static func guardIsAdministratorMiddleware() -> Middleware {
        return GuardIsAdministratorMiddleware()
    }
    
    static func guardIsModeratorMiddleware() -> Middleware {
        return GuardIsModeratorMiddleware()
    }
}
