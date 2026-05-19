//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during rule operations.
enum RuleError: String, Error {
    case incorrectRuleId
}

extension RuleError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectRuleId: return "Rule id is incorrect."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "rule"
    }

    var code: String {
        return self.rawValue
    }
}
