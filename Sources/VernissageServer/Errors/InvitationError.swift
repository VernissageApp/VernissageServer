//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during invitation operations.
enum InvitationError: String, Error {
    case maximumNumberOfInvitationsGenerated
    case cannotDeleteUsedInvitation
}

extension InvitationError: LocalizedTerminateError {
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

