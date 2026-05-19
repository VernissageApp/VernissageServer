//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during domain blocked domains operations.
enum InstanceBlockedDomainError: String, Error {
    case incorrectId
}

extension InstanceBlockedDomainError: LocalizedTerminateError {
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
        return "instanceBlockedDomain"
    }

    var code: String {
        return self.rawValue
    }
}
