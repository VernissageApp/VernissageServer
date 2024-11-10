//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Middleware which adds to response headers `Cache-Control` header set to one hour.
struct CacheControlMiddleware: AsyncMiddleware {
    private let cacheControl: CacheControl
    
    init(_ cacheControl: CacheControl) {
        self.cacheControl = cacheControl
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        switch self.cacheControl {
        case .public(let maxAge):
            response.headers.cacheControl = .init(isPublic: true, maxAge: maxAge)
        case .private(let maxAge):
            response.headers.cacheControl = .init(isPrivate: true, maxAge: maxAge)
        case .noStore:
            response.headers.cacheControl = .init(noStore: true, isPrivate: true, maxAge: 0)
        }
        
        return response
    }
}
