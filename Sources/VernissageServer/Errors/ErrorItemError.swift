//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during error items operations.
enum ErrorItemError: String, Error {
    case incorrectErrorItemId
}

extension ErrorItemError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectErrorItemId: return "Error item id is incorrect."
        }
    }

    var identifier: String {
        return "error-item"
    }

    var code: String {
        return self.rawValue
    }
}
