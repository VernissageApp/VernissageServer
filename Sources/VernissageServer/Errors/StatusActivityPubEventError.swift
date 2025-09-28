//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during status ActivityPub events operations.
enum StatusActivityPubEventError: String, Error {
    case sortColumnNotSupported
    case incorrectStatusEventId
}

extension StatusActivityPubEventError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .sortColumnNotSupported: return "Sort column is not supported."
        case .incorrectStatusEventId: return "Incorrect status event id."
        }
    }

    var identifier: String {
        return "status-activity-pub-event"
    }

    var code: String {
        return self.rawValue
    }
}
