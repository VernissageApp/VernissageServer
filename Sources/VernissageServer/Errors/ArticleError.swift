//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during articles operations.
enum ArticleError: String, Error {
    case incorrectArticleId
}

extension ArticleError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectArticleId: return "Incorrect article id."
        }
    }

    var identifier: String {
        return "article"
    }

    var code: String {
        return self.rawValue
    }
}
