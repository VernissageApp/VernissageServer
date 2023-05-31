import Vapor
import ExtendedError

enum EntityForbiddenError: String, Error {
    case userForbidden
    case refreshTokenForbidden
}

extension EntityForbiddenError: TerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .userForbidden: return "Access to specified user is forbidden."
        case .refreshTokenForbidden: return "Access to specified refresh token is forbidden."
        }
    }

    var identifier: String {
        return "entity-forbidden"
    }

    var code: String {
        return self.rawValue
    }
}
