//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during user's blocked domains operations.
enum UserBlockedDomainError: String, Error {
    case incorrectId
}

extension UserBlockedDomainError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .incorrectId: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .incorrectId: return "Incorrect id."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "userBlockedDomain"
    }

    var code: String {
        return self.rawValue
    }
}
