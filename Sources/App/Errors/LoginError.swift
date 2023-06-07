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
    case emailNotConfirmed
    case saltCorrupted
}

extension LoginError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .invalidLoginCredentials: return "Given user name or password are invalid."
        case .userAccountIsBlocked: return "User account is blocked. User cannot login to the system right now."
        case .emailNotConfirmed: return "User email is not confirmed. User have to confirm his email first."
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
