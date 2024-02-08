//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum UserError: String, Error {
    case userAlreadyApproved
}

extension UserError: TerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .userAlreadyApproved: return "User account is already apporoved."
        }
    }

    var identifier: String {
        return "user"
    }

    var code: String {
        return self.rawValue
    }
}
