//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during invitation operations.
enum InvitationError: String, Error {
    case maximumNumberOfInvitationsGenerated
    case cannotDeleteUsedInvitation
    case invalidId
}

extension InvitationError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .maximumNumberOfInvitationsGenerated, .cannotDeleteUsedInvitation: return .forbidden
        case .invalidId: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .maximumNumberOfInvitationsGenerated: return "Maximum number of invitations has been already generated."
        case .cannotDeleteUsedInvitation: return "Cannot delete already used invitation."
        case .invalidId: return "Invalid invitation id."
        }
    }
    
    var parameters: [String : String]? {
        return nil
    }

    var identifier: String {
        return "invitation"
    }

    var code: String {
        return self.rawValue
    }
}

