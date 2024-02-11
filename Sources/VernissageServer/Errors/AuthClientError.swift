//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during OAuth client operations.
enum AuthClientError: String, Error {
    case authClientWithUriExists
    case incorrectAuthClientId
}

extension AuthClientError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .authClientWithUriExists: return "Authentication client with specified uri already exists."
        case .incorrectAuthClientId: return "Authentication client id is incorrect."
        }
    }

    var identifier: String {
        return "auth-client"
    }

    var code: String {
        return self.rawValue
    }
}
