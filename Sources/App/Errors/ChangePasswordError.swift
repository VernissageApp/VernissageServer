import Vapor
import ExtendedError

enum ChangePasswordError: String, Error {
    case userNotFound
    case invalidOldPassword
    case userAccountIsBlocked
    case emailNotConfirmed
}

extension ChangePasswordError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .userNotFound: return "User was not found."
        case .invalidOldPassword: return "Given old password is invalid."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        case .emailNotConfirmed: return "User email is not confirmed. User have to confirm his email first."
        }
    }

    var identifier: String {
        return "change-password"
    }

    var code: String {
        return self.rawValue
    }
}
