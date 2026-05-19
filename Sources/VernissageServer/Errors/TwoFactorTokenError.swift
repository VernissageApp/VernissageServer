//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during operations with two factor authorization tokens.
enum TwoFactorTokenError: String, Error {
    case cannotEncodeKey
    case headerNotExists
    case tokenNotValid
}

extension TwoFactorTokenError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .tokenNotValid:
            return .forbidden
        default:
            return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .cannotEncodeKey: return "Cannot encode key to base32 data."
        case .headerNotExists: return "Header X-Auth-2FA with code not exists."
        case .tokenNotValid: return "Token is not valid."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "towFactorTokens"
    }

    var code: String {
        return self.rawValue
    }
}
