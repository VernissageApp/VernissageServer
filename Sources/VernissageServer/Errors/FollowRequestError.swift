//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum FollowRequestError: Error {
    case missingFollowEntity(Int64, Int64)
    case missingSourceUser(Int64)
    case missingTargetUser(Int64)
    case missingActivityPubActionId
    case missingPrivateKey(String)
}

extension FollowRequestError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingFollowEntity, .missingSourceUser, .missingTargetUser: return .notFound
        case .missingActivityPubActionId, .missingPrivateKey: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .missingFollowEntity(let sourceUserId, let targetUserId): return "Follow entity (sourceUserId: '\(sourceUserId)', targetUserId: \(targetUserId) not exists in local database."
        case .missingSourceUser(let userId): return "Missing source user '\(userId)' in database."
        case .missingTargetUser(let userId): return "Missing target user '\(userId)' in database."
        case .missingActivityPubActionId: return "Activity Pub action id in follow request is missing."
        case .missingPrivateKey(let userName): return "Private key for user \(userName) not exists in local database."
        }
    }

    var identifier: String {
        return "follow-request"
    }

    var code: String {
        switch self {
        case .missingFollowEntity: return "missingFollowEntity"
        case .missingSourceUser: return "missingSourceUser"
        case .missingTargetUser: return "missingTargetUser"
        case .missingActivityPubActionId: return "missingActivityPubActionId"
        case .missingPrivateKey: return "missingPrivateKey"
        }
    }
}
