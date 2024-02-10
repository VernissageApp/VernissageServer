//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum InvitationError: String, Error {
    case maximumNumberOfInvitationsGenerated
    case cannotDeleteUsedInvitation
}

extension InvitationError: TerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .maximumNumberOfInvitationsGenerated: return "Maximum number of invitations has been already generated."
        case .cannotDeleteUsedInvitation: return "Cannot delete already used invitation."
        }
    }

    var identifier: String {
        return "invitation"
    }

    var code: String {
        return self.rawValue
    }
}

