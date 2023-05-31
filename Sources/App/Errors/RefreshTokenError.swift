import Vapor
import ExtendedError

enum RefreshTokenError: String, Error {
    case userIdNotSpecified
    case refreshTokenNotExists
    case refreshTokenRevoked
    case refreshTokenExpired
}

extension RefreshTokenError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .refreshTokenNotExists: return "Refresh token not exists or it's expired."
        case .userIdNotSpecified: return "User id must be specified for refresh token."
        case .refreshTokenRevoked: return "Refresh token was revoked."
        case .refreshTokenExpired: return "Refresh token was expired."
        }
    }

    var identifier: String {
        return "refresh"
    }

    var code: String {
        return self.rawValue
    }
}
