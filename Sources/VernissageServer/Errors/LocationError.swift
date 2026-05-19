//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during operations on localizations.
enum LocationError: String, Error {
    case incorrectLocationId
    case queryIsRequired
}

extension LocationError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectLocationId: return "Location id is incorrect."
        case .queryIsRequired: return "Query is required."
        }
    }
    
    var parameters: [String : String]? {
        return nil
    }

    var identifier: String {
        return "location"
    }

    var code: String {
        return self.rawValue
    }
}
