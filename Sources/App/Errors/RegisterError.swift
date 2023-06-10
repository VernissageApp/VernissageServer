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
    case missingEmail
    case missingEmailConfirmationGuid
    case userHaveToAcceptAgreeent
    case reasonIsMandatory
    case invitationTokenIsInvalid
    case invitationTokenHasBeenUsed
}

extension RegisterError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .registrationIsDisabled, .invitationTokenIsInvalid, .invitationTokenHasBeenUsed: return .forbidden
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
        case .missingEmail: return "Email has not been specify but it's mandatory."
        case .missingEmailConfirmationGuid: return "Email confirmation guid has not been generated."
        case .userHaveToAcceptAgreeent: return "User have to accept agreement."
        case .reasonIsMandatory: return "Reason is mandatory when only registration by approval is enabled."
        case .invitationTokenIsInvalid: return "Invitation token is invalid."
        case .invitationTokenHasBeenUsed: return "Invitation token has been used."
        }
    }

    var identifier: String {
        return "register"
    }

    var code: String {
        return self.rawValue
    }
}
