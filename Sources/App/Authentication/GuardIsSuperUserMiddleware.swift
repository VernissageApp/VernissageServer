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
