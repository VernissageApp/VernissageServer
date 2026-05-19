//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned when confirming email address
enum ConfirmEmailError: String, Error {
    case invalidIdOrToken
}

extension ConfirmEmailError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .invalidIdOrToken: return "Invalid user Id or token. Email cannot be approved."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "confirmEmail"
    }

    var code: String {
        return self.rawValue
    }
}
