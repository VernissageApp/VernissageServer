//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during password change operations.
enum ChangePasswordError: String, Error {
    case userNotFound
    case invalidOldPassword
    case userAccountIsBlocked
    case emailNotConfirmed
    case saltCorrupted
}

extension ChangePasswordError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userNotFound: return .notFound
        case .invalidOldPassword: return .badRequest
        case .userAccountIsBlocked: return .forbidden
        case .emailNotConfirmed: return .forbidden
        case .saltCorrupted: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .userNotFound: return "Signed user was not found in the database."
        case .invalidOldPassword: return "Given old password is invalid."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        case .emailNotConfirmed: return "User email is not confirmed. User have to confirm his email first."
        case .saltCorrupted: return "Password has been corrupted. Please contact with portal administrator."
        }
    }

    var identifier: String {
        return "change-password"
    }

    var code: String {
        return self.rawValue
    }
}
