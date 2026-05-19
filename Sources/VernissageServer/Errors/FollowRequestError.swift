//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned when requesting to follow users.
enum FollowRequestError: Error {
    case missingFollowEntity(Int64, Int64)
    case missingSourceUser(Int64)
    case missingTargetUser(Int64)
    case missingActivityPubActionId
    case missingPrivateKey(String)
    case incorrectId
    case accountHasBeenMoved
}

extension FollowRequestError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingFollowEntity, .missingSourceUser, .missingTargetUser: return .notFound
        case .missingActivityPubActionId, .missingPrivateKey: return .internalServerError
        case .accountHasBeenMoved: return .forbidden
        case .incorrectId: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .missingFollowEntity(let sourceUserId, let targetUserId): return "Follow entity (sourceUserId: '\(sourceUserId)', targetUserId: \(targetUserId) not exists in local database."
        case .missingSourceUser(let userId): return "Missing source user '\(userId)' in database."
        case .missingTargetUser(let userId): return "Missing target user '\(userId)' in database."
        case .missingActivityPubActionId: return "Activity Pub action id in follow request is missing."
        case .missingPrivateKey(let userName): return "Private key for user \(userName) not exists in local database."
        case .accountHasBeenMoved: return "Target account has been moved and cannot accept new followers."
        case .incorrectId: return "Incorrect id in follow request."
        }
    }

    var parameters: [String : String]? {
        switch self {
        case .missingFollowEntity(let sourceUserId, let targetUserId): return ["sourceUserId": sourceUserId.description, "targetUserId": targetUserId.description]
        case .missingSourceUser(let userId): return ["userId": userId.description]
        case .missingTargetUser(let userId): return ["userId": userId.description]
        case .missingPrivateKey(let userName): return ["userName": userName]
        default: return nil
        }
    }
    
    var identifier: String {
        return "followRequest"
    }

    var code: String {
        switch self {
        case .missingFollowEntity: return "missingFollowEntity"
        case .missingSourceUser: return "missingSourceUser"
        case .missingTargetUser: return "missingTargetUser"
        case .missingActivityPubActionId: return "missingActivityPubActionId"
        case .missingPrivateKey: return "missingPrivateKey"
        case .accountHasBeenMoved: return "accountHasBeenMoved"
        case .incorrectId: return "incorrectId"
        }
    }
}
