//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during RSS feed operations.
enum RssError: String, Error {
    case userNameIsRequired
    case categoryNameIsRequired
    case hashtagNameIsRequired
}

extension RssError: LocalizedTerminateError {
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
        return "rss"
    }

    var code: String {
        return self.rawValue
    }
}
