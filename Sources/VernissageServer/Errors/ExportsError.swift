//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during exports operations.
enum ExportsError: String, Error {
    case cannotConvertToData
}

extension ExportsError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .internalServerError
    }

    var reason: String {
        switch self {
        case .cannotConvertToData: return "Cannot convert invitation to data."
        }
    }

    var identifier: String {
        return "exports"
    }

    var code: String {
        return self.rawValue
    }
}

