//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during password restore operations.
enum ForgotPasswordError: String, Error {
    case userAccountIsBlocked
    case tokenNotGenerated
    case tokenExpired
    case passwordNotHashed
    case saltCorrupted
    case emailIsEmpty
}

extension ForgotPasswordError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .emailIsEmpty: return .badRequest
        case .userAccountIsBlocked: return .forbidden
        case .tokenExpired: return .forbidden
        case .tokenNotGenerated: return .internalServerError
        case .passwordNotHashed: return .internalServerError
        case .saltCorrupted: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .userAccountIsBlocked: return "User account is blocked. You cannot change password right now."
        case .tokenNotGenerated: return "Forgot password token wasn't generated. It's really strange."
        case .tokenExpired: return "Token which allows to change password expired. User have to repeat forgot password process."
        case .passwordNotHashed: return "Password was not hashed successfully."
        case .saltCorrupted: return "Password has been corrupted. Please contact with portal administrator."
        case .emailIsEmpty: return "User email is empty. Cannot send email with token."
        }
    }

    var identifier: String {
        return "forgotPassword"
    }

    var code: String {
        return self.rawValue
    }
}
