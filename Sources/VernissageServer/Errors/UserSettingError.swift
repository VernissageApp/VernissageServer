//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during user setting operations.
enum UserSettingError: String, Error {
    case keyIsRequired
}

extension UserSettingError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .keyIsRequired: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .keyIsRequired: return "Key is required."
        }
    }

    var identifier: String {
        return "user-setting"
    }

    var code: String {
        return self.rawValue
    }
}
