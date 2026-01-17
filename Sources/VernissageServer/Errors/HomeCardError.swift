//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during home card operations.
enum HomeCardError: String, Error {
    case incorrectHomeCardId
}

extension HomeCardError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .incorrectHomeCardId: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .incorrectHomeCardId: return "Home card id is incorrect."
        }
    }

    var identifier: String {
        return "home-card"
    }

    var code: String {
        return self.rawValue
    }
}
