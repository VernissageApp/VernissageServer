import Vapor
import ExtendedError

enum ForgotPasswordError: String, Error {
    case userAccountIsBlocked
    case tokenNotGenerated
    case tokenExpired
    case passwordNotHashed
}

extension ForgotPasswordError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .userAccountIsBlocked: return "User account is blocked. You cannot change password right now."
        case .tokenNotGenerated: return "Forgot password token wasn't generated. It's really strange."
        case .tokenExpired: return "Token which allows to change password expired. User have to repeat forgot password process."
        case .passwordNotHashed: return "Password was not hashed successfully."
        }
    }

    var identifier: String {
        return "forgotPassword"
    }

    var code: String {
        return self.rawValue
    }
}
