import Vapor
import ExtendedError

enum OpenIdConnectError: String, Error {
    case invalidClientName
    case clientNotFound
    case codeTokenNotFound
    case invalidAuthenticateToken
    case authenticateTokenExpirationDateNotFound
    case autheticateTokenExpired
    case userAccountIsBlocked
}

extension OpenIdConnectError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .invalidClientName: return "Client name have to be specified in the URL."
        case .clientNotFound: return "Client with given name was not found."
        case .codeTokenNotFound: return "Code token was not found."
        case .invalidAuthenticateToken: return "Authenticate token is invalid."
        case .authenticateTokenExpirationDateNotFound: return "Authentication token don't have expiration date."
        case .autheticateTokenExpired: return "Authentication token expired."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        }
    }

    var identifier: String {
        return "login"
    }

    var code: String {
        return self.rawValue
    }
}
