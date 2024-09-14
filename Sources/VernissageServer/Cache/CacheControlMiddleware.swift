//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Middleware which adds to response headers `Cache-Control` header set to one hour.
struct CacheControlMiddleware: AsyncMiddleware {    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        response.headers.cacheControl = .init(isPublic: true, maxAge: 3600)
        
        return response
    }
}
