//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// An authenticator to verify the existence and validity of the JWT token.
///
/// First we check if we have token in the cooke `access-token`, id not then
/// we check if we have token as `Authorization: Bearer` header.
struct UserAuthenticator: AsyncRequestAuthenticator {
    typealias User = UserPayload
    
    func authenticate(request: Vapor.Request) async throws {
        guard let accessToken = self.getAccessToken(request: request) else {
            return
        }
        
        let authorizationPayload = try request.jwt.verify(accessToken, as: UserPayload.self)
        request.auth.login(authorizationPayload)
    }
    
    private func getAccessToken(request: Vapor.Request) -> String? {
        if let cookieAccessToken = request.cookies[Constants.accessTokenName], cookieAccessToken.string.isEmpty == false {
            return cookieAccessToken.string
        }
        
        if let bearerAuthorization = request.headers.bearerAuthorization {
            return bearerAuthorization.token
        }
        
        return nil
    }
}
