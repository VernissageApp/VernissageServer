//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned when the user does not have the right to access the specific actions.
enum ActionsForbiddenError: String, Error {
    case localTimelineForbidden
    case trendingForbidden
    case editorsStatusesChoiceForbidden
    case editorsUsersChoiceForbidden
    case hashtagsForbidden
    case categoriesForbidden
    case camerasForbidden
    case lensesForbidden
    case filmsForbidden
}

extension ActionsForbiddenError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .unauthorized
    }

    var reason: String {
        switch self {
        case .localTimelineForbidden: return "Access to local timeline is forbidden."
        case .trendingForbidden: return "Access to trending is forbidden."
        case .editorsStatusesChoiceForbidden: return "Access to editor's statuses choice is forbidden."
        case .editorsUsersChoiceForbidden: return "Access to editor's users choice is forbidden."
        case .hashtagsForbidden: return "Access to hashtags is forbidden."
        case .categoriesForbidden: return "Access to categories is forbidden."
        case .camerasForbidden: return "Access to cameras is forbidden."
        case .lensesForbidden: return "Access to lenses is forbidden."
        case .filmsForbidden: return "Access to films is forbidden."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "actionsForbidden"
    }

    var code: String {
        return self.rawValue
    }
}
