//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during rule operations.
enum RuleError: String, Error {
    case incorrectRuleId
}

extension RuleError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectRuleId: return "Rule id is incorrect."
        }
    }

    var identifier: String {
        return "rule"
    }

    var code: String {
        return self.rawValue
    }
}
