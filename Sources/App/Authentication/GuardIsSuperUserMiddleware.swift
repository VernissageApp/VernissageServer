//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct GuardIsSuperUserMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let authorizationPayload = request.auth.get(UserPayload.self) else {
            return request.fail(.unauthorized)
        }
        
        guard authorizationPayload.isSuperUser else {
            return request.fail(.forbidden)
        }
        
        return next.respond(to: request)
    }
}
