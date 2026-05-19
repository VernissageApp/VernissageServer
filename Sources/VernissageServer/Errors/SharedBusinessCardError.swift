//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during shared business cards operations.
enum SharedBusinessCardError: String, Error {
    case incorrectSharedBusinessCardId
    case incorrectCode
    case businessCardNotFound
    case missingEmail
}

extension SharedBusinessCardError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectSharedBusinessCardId: return "Incorrect shared business card id."
        case .incorrectCode: return "Incorrect code."
        case .businessCardNotFound: return "Business card not found."
        case .missingEmail: return "Missing email."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "sharedBusinessCard"
    }

    var code: String {
        return self.rawValue
    }
}
