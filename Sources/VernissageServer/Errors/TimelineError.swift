//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during timeline operations.
enum TimelineError: String, Error {
    case categoryNameIsRequired
    case hashtagNameIsRequired
}

extension TimelineError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .categoryNameIsRequired: return "Category name is required."
        case .hashtagNameIsRequired: return "Hashtag name is required."
        }
    }

    var identifier: String {
        return "timeline"
    }

    var code: String {
        return self.rawValue
    }
}
