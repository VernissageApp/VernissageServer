import Vapor

struct UserAuthenticator: BearerAuthenticator {
    typealias User = UserPayload
    
    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        do {
            let authorizationPayload = try request.jwt.verify(bearer.token, as: UserPayload.self)
            request.auth.login(authorizationPayload)
            return request.success()
        } catch {
            return request.success()
        }
   }
}
