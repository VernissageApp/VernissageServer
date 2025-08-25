//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during search operations.
enum SearchError: String, Error {
    case queryIsRequired
}

extension SearchError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .queryIsRequired: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .queryIsRequired: return "Query is required."
        }
    }

    var identifier: String {
        return "search"
    }

    var code: String {
        return self.rawValue
    }
}
