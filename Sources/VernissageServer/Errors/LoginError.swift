//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned when the user logs in to the system.
enum LoginError: String, Error {
    case invalidLoginCredentials
    case userAccountIsBlocked
    case userAccountIsNotApproved
    case saltCorrupted
    case twoFactorTokenNotFound
    case loginAttemptsExceeded
}

extension LoginError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userAccountIsBlocked, .userAccountIsNotApproved: return .forbidden
        case .saltCorrupted: return .internalServerError
        case .twoFactorTokenNotFound: return .preconditionRequired
        default: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .invalidLoginCredentials: return "Given user name or password are invalid."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        case .userAccountIsNotApproved: return "User account is not approved yet. User cannot login to the system right now."
        case .saltCorrupted: return "Password has been corrupted. Please contact with portal administrator."
        case .twoFactorTokenNotFound: return "Token for two factor authentication is required."
        case .loginAttemptsExceeded: return "Too many failed logins. Please try again in 5 minutes."
        }
    }

    var identifier: String {
        return "login"
    }

    var code: String {
        return self.rawValue
    }
}
