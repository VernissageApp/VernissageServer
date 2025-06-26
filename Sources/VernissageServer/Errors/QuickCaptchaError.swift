//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during generating captcha.
enum QuickCaptchaError: String, Error {
    case keyLengthIsIncorrect
}

extension QuickCaptchaError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .keyLengthIsIncorrect: return "Key length is incorrect, should be 16 characters."
        }
    }

    var identifier: String {
        return "quick-captcha"
    }

    var code: String {
        return self.rawValue
    }
}
