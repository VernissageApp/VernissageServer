//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during user account operations.
enum AccountError: String, Error {
    case emailIsAlreadyConfirmed
    case userNameIsRequired
    case userHaveToBeAuthenticated
}

extension AccountError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userHaveToBeAuthenticated: return .unauthorized
        default: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .emailIsAlreadyConfirmed: return "Email is already confirmed."
        case .userNameIsRequired: return "User name is required."
        case .userHaveToBeAuthenticated: return "User have to be authenticated."
        }
    }

    var identifier: String {
        return "account"
    }

    var code: String {
        return self.rawValue
    }
}
