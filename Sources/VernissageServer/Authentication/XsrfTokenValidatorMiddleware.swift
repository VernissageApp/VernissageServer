//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// A guard that checks if cookies authorized requests contains also XSRF token header.
/// That mechanism prevents XSRF attacks.
struct XsrfTokenValidatorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // If access token exists in requests headers we don't have to validate XSRF token.
        if request.headers.bearerAuthorization != nil {
            return try await next.respond(to: request)
        }
        
        // XSRF token from cookie.
        guard let xsrfTokenFromCookie = request.cookies[Constants.xsrfTokenName], xsrfTokenFromCookie.string.isEmpty == false else {
            throw XsrfValidationError.xsrfTokenNotExistsInCookie
        }
        
        // XSRF token from headers.
        guard let xsrfTokenFromHeader = request.headers.first(name: Constants.xsrfTokenHeader), xsrfTokenFromHeader.isEmpty == false else {
            throw XsrfValidationError.xsrfTokenNotExistsInHeader
        }
        
        // Tokens have to be the same if we want to process request.
        guard xsrfTokenFromCookie.string == xsrfTokenFromHeader else {
            throw XsrfValidationError.xsrfTokensAreDifferent
        }
        
        return try await next.respond(to: request)
    }
}
