//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during XSRF token validation.
enum XsrfValidationError: String, Error {
    case xsrfTokenNotExistsInHeader
    case xsrfTokenNotExistsInCookie
    case xsrfTokensAreDifferent
}

extension XsrfValidationError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .xsrfTokenNotExistsInHeader: return "XSRF token (X-XSRF-TOKEN) not exists in request header."
        case .xsrfTokenNotExistsInCookie: return "XSRF token (xsrf-token) not exists in the cookie."
        case .xsrfTokensAreDifferent: return "XSRF tokens are different in the cookie and header."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "xsrfValidation"
    }

    var code: String {
        return self.rawValue
    }
}
