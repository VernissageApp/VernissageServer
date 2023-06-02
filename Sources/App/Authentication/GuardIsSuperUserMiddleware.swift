//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct GuardIsSuperUserMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authorizationPayload = request.auth.get(UserPayload.self) else {
            throw Abort(.unauthorized)
        }
        
        guard authorizationPayload.isSuperUser else {
            throw Abort(.forbidden)
        }
        
        return try await next.respond(to: request)
    }
}
