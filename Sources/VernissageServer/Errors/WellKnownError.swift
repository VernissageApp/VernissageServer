//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during well known metadata operations.
enum WellKnownError: Error {
    case accountNotFound(String)
}

extension WellKnownError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .accountNotFound: return .notFound
        }
    }

    var reason: String {
        switch self {
        case .accountNotFound(let account): return "Account '\(account)' not found."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "wellKnown"
    }

    var code: String {
        switch self {
        case .accountNotFound: return "accountNotFound"
        }
    }
}
