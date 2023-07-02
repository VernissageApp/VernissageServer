//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import JWT

struct UserPayload: JWTPayload, Authenticatable {
    var id: String
    var userName: String
    var email: String?
    var name: String?
    var exp: Date
    var avatarUrl: String?
    var headerUrl: String?
    var roles: [String]
    var isSuperUser: Bool

    func verify(using signer: JWTSigner) throws {
        // nothing to verify
    }
}

extension UserPayload {
    static func guardIsSuperUserMiddleware() -> Middleware {
        return GuardIsSuperUserMiddleware()
    }
}
