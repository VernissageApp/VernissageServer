//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during user role operations.
enum RoleError: String, Error {
    case incorrectRoleId
}

extension RoleError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectRoleId: return "Role id is incorrect."
        }
    }

    var parameters: [String : String]? {
        return nil
    }
    
    var identifier: String {
        return "role"
    }

    var code: String {
        return self.rawValue
    }
}
