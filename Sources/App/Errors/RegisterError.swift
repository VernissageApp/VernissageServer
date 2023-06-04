//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum RegisterError: String, Error {
    case securityTokenIsMandatory
    case securityTokenIsInvalid
    case userNameIsAlreadyTaken
    case userIdNotExists
    case invalidIdOrToken
    case emailIsAlreadyConnected
    case registrationIsDisabled
}

extension RegisterError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .registrationIsDisabled: return .forbidden
        default: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .securityTokenIsMandatory: return "Security token is mandatory (it should be provided from Google reCaptcha)."
        case .securityTokenIsInvalid: return "Security token is invalid (Google reCaptcha API returned that information)."
        case .userNameIsAlreadyTaken: return "User with provided user name already exists in the system."
        case .userIdNotExists: return "User Id not exists. Probably saving of the user entity failed."
        case .invalidIdOrToken: return "Invalid user Id or token. User have to activate account by reseting his password."
        case .emailIsAlreadyConnected: return "Email is already connected with other account."
        case .registrationIsDisabled: return "Registration is disabled."
        }
    }

    var identifier: String {
        return "register"
    }

    var code: String {
        return self.rawValue
    }
}
