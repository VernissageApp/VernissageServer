//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Middleware which adds to response security headers  such as `Referrer-Policy`, `Content-Security-Policy` etc.
struct SecurityHeadersMiddleware: AsyncMiddleware {

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        response.headers.replaceOrAdd(name: "Referrer-Policy", value: "same-origin")
        response.headers.replaceOrAdd(name: "Content-Security-Policy", value: "default-src 'none'; frame-ancestors 'none'; form-action 'none'")
        response.headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
        response.headers.replaceOrAdd(name: "Strict-Transport-Security", value: "max-age=31557600")
        
        return response
    }
}
