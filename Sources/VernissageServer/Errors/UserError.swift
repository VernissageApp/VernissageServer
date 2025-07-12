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
}

extension UserError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .userAlreadyApproved: return .forbidden
        case .sortColumnNotSupported: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .userAlreadyApproved: return "User account is already apporoved."
        case .sortColumnNotSupported: return "Sort column is not supported."
        }
    }

    var identifier: String {
        return "user"
    }

    var code: String {
        return self.rawValue
    }
}
