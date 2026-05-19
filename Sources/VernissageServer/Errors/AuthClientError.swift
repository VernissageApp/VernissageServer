//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during OAuth client operations.
enum AuthClientError: String, Error {
    case authClientWithUriExists
    case incorrectAuthClientId
}

extension AuthClientError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .authClientWithUriExists: return "Authentication client with specified uri already exists."
        case .incorrectAuthClientId: return "Authentication client id is incorrect."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "authClient"
    }

    var code: String {
        return self.rawValue
    }
}
