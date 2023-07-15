//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum EntityNotFoundError: String, Error {
    case userNotFound
    case refreshTokenNotFound
    case roleNotFound
    case authClientNotFound
    case settingNotFound
    case attachmentNotFound
}

extension EntityNotFoundError: TerminateError {
    var status: HTTPResponseStatus {
        return .notFound
    }

    var reason: String {
        switch self {
        case .userNotFound: return "User not exists."
        case .refreshTokenNotFound: return "Refresh token not exists."
        case .roleNotFound: return "Role not exists."
        case .authClientNotFound: return "Authentication client not exists."
        case .settingNotFound: return "Setting not exists."
        case .attachmentNotFound: return "Attachment not exists."
        }
    }

    var identifier: String {
        return "entity-not-found"
    }

    var code: String {
        return self.rawValue
    }
}
