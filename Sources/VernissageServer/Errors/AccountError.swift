//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during user account operations.
enum AccountError: String, Error {
    case emailIsAlreadyConfirmed
}

extension AccountError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .emailIsAlreadyConfirmed: return "Email is already confirmed."
        }
    }

    var identifier: String {
        return "account"
    }

    var code: String {
        return self.rawValue
    }
}
