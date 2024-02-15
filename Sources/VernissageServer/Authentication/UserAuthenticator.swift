//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// An authenticator to verify the existence and validity of the JWT token.
struct UserAuthenticator: AsyncBearerAuthenticator {
    typealias User = UserPayload
    
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let authorizationPayload = try request.jwt.verify(bearer.token, as: UserPayload.self)
        request.auth.login(authorizationPayload)
   }
}
