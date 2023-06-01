//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum RoleError: String, Error {
    case roleWithCodeExists
    case incorrectRoleId
}

extension RoleError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .roleWithCodeExists: return "Role with specified code already exists."
        case .incorrectRoleId: return "Role id is incorrect."
        }
    }

    var identifier: String {
        return "role"
    }

    var code: String {
        return self.rawValue
    }
}
