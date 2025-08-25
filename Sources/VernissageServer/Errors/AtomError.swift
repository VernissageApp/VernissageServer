//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during Atom feed operations.
enum AtomError: String, Error {
    case userNameIsRequired
    case categoryNameIsRequired
    case hashtagNameIsRequired
}

extension AtomError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .userNameIsRequired: return "User name is required."
        case .categoryNameIsRequired: return "Category name is required."
        case .hashtagNameIsRequired: return "Hashtag name is required."
        }
    }

    var identifier: String {
        return "atom"
    }

    var code: String {
        return self.rawValue
    }
}
