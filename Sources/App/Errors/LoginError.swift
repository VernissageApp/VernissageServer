//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum LoginError: String, Error {
    case invalidLoginCredentials
    case userAccountIsBlocked
    case userAccountIsNotApproved
    case saltCorrupted
}

extension LoginError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userAccountIsBlocked, .userAccountIsNotApproved: return .forbidden
        case .saltCorrupted: return .internalServerError
        default: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .invalidLoginCredentials: return "Given user name or password are invalid."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        case .userAccountIsNotApproved: return "User account is not approved yet. User cannot login to the system right now."
        case .saltCorrupted: return "Password has been corrupted. Please contact with portal administrator."
        }
    }

    var identifier: String {
        return "login"
    }

    var code: String {
        return self.rawValue
    }
}
