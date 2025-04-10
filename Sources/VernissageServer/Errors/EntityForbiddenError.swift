//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned when the user does not have the right to access the object.
enum EntityForbiddenError: String, Error {
    case userForbidden
    case refreshTokenForbidden
    case attachmentForbidden
    case statusForbidden
}

extension EntityForbiddenError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .userForbidden: return "Access to specified user is forbidden."
        case .refreshTokenForbidden: return "Access to specified refresh token is forbidden."
        case .attachmentForbidden: return "Access to attachment is forbidden."
        case .statusForbidden: return "Access to specified status is forbidden."
        }
    }

    var identifier: String {
        return "entity-forbidden"
    }

    var code: String {
        return self.rawValue
    }
}
