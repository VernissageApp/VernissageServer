//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during report operations.
enum ReportError: String, Error {
    case incorrectId
}

extension ReportError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .incorrectId: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .incorrectId: return "Incorrect id."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "report"
    }

    var code: String {
        return self.rawValue
    }
}
