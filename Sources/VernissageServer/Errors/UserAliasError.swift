//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during user aliases operations.
enum UserAliasError: String, Error {
    case userAliasAlreadyExist
    case incorrectUserAliasId
    case cannotVerifyRemoteAccount
}

extension UserAliasError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectUserAliasId: return "User alias id is incorrect."
        case .userAliasAlreadyExist: return "User alias already exist."
        case .cannotVerifyRemoteAccount: return "Cannot verify remote account."
        }
    }

    var identifier: String {
        return "user-alias"
    }

    var code: String {
        return self.rawValue
    }
}
