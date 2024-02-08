//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum RefreshTokenError: String, Error {
    case userIdNotSpecified
    case refreshTokenNotExists
    case refreshTokenRevoked
    case refreshTokenExpired
}

extension RefreshTokenError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .refreshTokenNotExists: return .notFound
        case .userIdNotSpecified: return .badRequest
        case .refreshTokenRevoked: return .forbidden
        case .refreshTokenExpired: return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .refreshTokenNotExists: return "Refresh token not exists or it's expired."
        case .userIdNotSpecified: return "User id must be specified for refresh token."
        case .refreshTokenRevoked: return "Refresh token was revoked."
        case .refreshTokenExpired: return "Refresh token was expired."
        }
    }

    var identifier: String {
        return "refresh"
    }

    var code: String {
        return self.rawValue
    }
}
