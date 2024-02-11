//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during operations on localizations.
enum LocationError: String, Error {
    case incorrectLocationId
}

extension LocationError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectLocationId: return "Location id is incorrect."
        }
    }

    var identifier: String {
        return "location"
    }

    var code: String {
        return self.rawValue
    }
}
