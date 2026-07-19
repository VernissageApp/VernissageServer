//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during timeline marker operations.
enum TimelineMarkerError: String, Error {
    case incorrectStatusId
    case incorrectTimeline
}

extension TimelineMarkerError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectStatusId: return "Incorrect status id."
        case .incorrectTimeline: return "Incorrect timeline."
        }
    }

    var parameters: [String : String]? {
        return nil
    }

    var identifier: String {
        return "timelineMarker"
    }

    var code: String {
        return self.rawValue
    }
}
