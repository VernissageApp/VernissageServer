//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during business card operations.
enum BusinessCardError: String, Error {
    case businessCardAlreadyExists
}

extension BusinessCardError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .businessCardAlreadyExists: return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .businessCardAlreadyExists: return "Business card already exists."
        }
    }

    var identifier: String {
        return "business-card"
    }

    var code: String {
        return self.rawValue
    }
}
