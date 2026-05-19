//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during hashtags operations.
enum HashtagError: String, Error {
    case hashtagNameIsRequired
    case hashtagNameIsTooLong
}

extension HashtagError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .hashtagNameIsRequired: return "Hashtag name is required."
        case .hashtagNameIsTooLong: return "Hashtag name is too long."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "hashtag"
    }

    var code: String {
        return self.rawValue
    }
}
