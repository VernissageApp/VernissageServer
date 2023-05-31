import Vapor
import JWT

struct UserPayload: JWTPayload, Authenticatable {
    var id: UUID
    var userName: String
    var email: String
    var name: String?
    var exp: Date
    var gravatarHash: String
    var roles: [String]
    var isSuperUser: Bool

    func verify(using signer: JWTSigner) throws {
        // nothing to verify
    }
}

extension UserPayload {
    static func guardIsSuperUserMiddleware() -> Middleware {
        return GuardIsSuperUserMiddleware()
    }
}
