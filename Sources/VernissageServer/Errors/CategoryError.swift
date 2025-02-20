//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during category operations.
enum CategoryError: String, Error {
    case categoryExists
    case incorrectCategoryId
    case categoryCannotBeDeletedBecauseItIsInUse
}

extension CategoryError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .categoryExists: return "Category already exists."
        case .incorrectCategoryId: return "Incorrect category id."
        case .categoryCannotBeDeletedBecauseItIsInUse: return "Category cannot be deleted because it is in use."
        }
    }

    var identifier: String {
        return "category"
    }

    var code: String {
        return self.rawValue
    }
}
