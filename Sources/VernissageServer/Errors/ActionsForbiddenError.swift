//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned when the user does not have the right to access the specific actions.
enum ActionsForbiddenError: String, Error {
    case localTimelineForbidden
    case trendingForbidden
    case editorsChoiceForbidden
    case hashtagsForbidden
    case categoriesForbidden
}

extension ActionsForbiddenError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .unauthorized
    }

    var reason: String {
        switch self {
        case .localTimelineForbidden: return "Access to local timeline is forbidden."
        case .trendingForbidden: return "Access to trending is forbidden."
        case .editorsChoiceForbidden: return "Access to editor's choice is forbidden."
        case .hashtagsForbidden: return "Access to hashtags is forbidden."
        case .categoriesForbidden: return "Access to categories is forbidden."
        }
    }

    var identifier: String {
        return "actions-forbidden"
    }

    var code: String {
        return self.rawValue
    }
}
