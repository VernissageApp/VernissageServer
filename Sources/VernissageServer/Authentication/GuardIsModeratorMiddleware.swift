//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// A guard that checks whether a logged-in user is an moderator.
struct GuardIsModeratorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard request.isAdministrator || request.isModerator else {
            throw Abort(.forbidden)
        }
        
        return try await next.respond(to: request)
    }
}
