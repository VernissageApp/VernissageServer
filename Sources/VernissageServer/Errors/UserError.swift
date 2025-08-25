//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned when operating on user data.
enum UserError: String, Error {
    case userAlreadyApproved
    case sortColumnNotSupported
    case userNameIsRequired
    case roleIsRequired
}

extension UserError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userAlreadyApproved: return .forbidden
        case .sortColumnNotSupported, .userNameIsRequired, .roleIsRequired: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .userAlreadyApproved: return "User account is already apporoved."
        case .sortColumnNotSupported: return "Sort column is not supported."
        case .userNameIsRequired: return "User name is required."
        case .roleIsRequired: return "User role is required."
        }
    }

    var identifier: String {
        return "user"
    }

    var code: String {
        return self.rawValue
    }
}
