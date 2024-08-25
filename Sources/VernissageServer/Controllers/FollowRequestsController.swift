//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension FollowRequestsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("follow-requests")
    
    func boot(routes: RoutesBuilder) throws {
        let relationshipsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(FollowRequestsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        relationshipsGroup
            .grouped(EventHandlerMiddleware(.followRequestList))
            .get(use: list)
        
        relationshipsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.followRequestApprove))
            .post(":id", "approve", use: approve)
        
        relationshipsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.followRequestReject))
            .post(":id", "reject", use: reject)
    }
}

/// Controller for managing user's follow requests.
///
/// In the ActivityPub protocol user, can have manual acceptance of followers enabled.
/// This controller is used to retrieve a list of requests to accept a follower and to accept or reject those requests.
///
/// > Important: Base controller URL: `/api/v1/follow-requests`.
final class FollowRequestsController {
    
    /// List of requests to approve.
    ///
    /// The endpoint returns a list of requests from followers to accept.
    /// The list supports paging using query parameters.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/follow-requests`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/follow-requests" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "data": [
    ///         {
    ///             "followedBy": false,
    ///             "following": false,
    ///             "mutedNotifications": false,
    ///             "mutedReblogs": false,
    ///             "mutedStatuses": false,
    ///             "requested": false,
    ///             "requestedBy": false,
    ///             "userId": "7250729777261258752"
    ///         }
    ///     ],
    ///     "maxId": "7250729777261258752",
    ///     "minId": "7268212003553077249"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable relationships.
    func list(request: Request) async throws -> LinkableResultDto<RelationshipDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        let linkableParams = request.linkableParams()
        let followsService = request.application.services.followsService
        let linkableResult = try await followsService.toApprove(on: request, userId: authorizationPayloadId, linkableParams: linkableParams)
        
        return LinkableResultDto(basedOn: linkableResult)
    }
    
    /// Approving follow request.
    ///
    /// The endpoint is used to accept a single follow request.
    ///
    /// > Important: Endpoint URL: `/api/v1/follow-requests/:userId/approve`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/follow-requests/7265253398152519681/approve" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "followedBy": true,
    ///     "following": true,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7265253398152519681"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `FollowRequestError.missingSourceUser` if missing source user in database.
    /// - Throws: `FollowRequestError.missingTargetUser` if missing target user in database.
    /// - Throws: `FollowRequestError.missingFollowEntity` if follow entity not exists in local database.
    /// - Throws: `FollowRequestError.missingActivityPubActionId` if Activity Pub action id in follow request is missing.
    /// - Throws: `FollowRequestError.missingPrivateKey` if private key for user not exists in local database.
    func approve(request: Request) async throws -> RelationshipDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let userId = id.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let sourceUser = try await User.query(on: request.db).filter(\.$id == userId).first() else {
            throw FollowRequestError.missingSourceUser(userId)
        }
        
        guard let targetUser = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw FollowRequestError.missingTargetUser(authorizationPayloadId)
        }

        let followsService = request.application.services.followsService
        guard let follow = try await followsService.get(on: request.db, sourceId: userId, targetId: authorizationPayloadId) else {
            throw FollowRequestError.missingFollowEntity(userId, authorizationPayloadId)
        }
        
        if sourceUser.isLocal == false && follow.activityId == nil {
            throw FollowRequestError.missingActivityPubActionId
        }
                
        guard let privateKey = targetUser.privateKey else {
            throw FollowRequestError.missingPrivateKey(targetUser.userName)
        }
        
        // Approve in local database.
        try await followsService.approve(on: request.db, sourceId: userId, targetId: authorizationPayloadId)
        
        // Send information to remote server (for remote accounts) server about approved follow.
        if sourceUser.isLocal == false {
            try await informRemote(on: request,
                                   approved: true,
                                   requesting: sourceUser.activityPubProfile,
                                   asked: targetUser.activityPubProfile,
                                   inbox: sourceUser.userInbox,
                                   withId: follow.requireID(),
                                   acceptedId: follow.activityId,
                                   privateKey: privateKey)
        }
        
        let relationshipsService = request.application.services.relationshipsService
        let relationships = try await relationshipsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: [userId])
        return relationships.first ?? RelationshipDto(
            userId: id,
            following: false,
            followedBy: false,
            requested: false,
            requestedBy: false,
            mutedStatuses: false,
            mutedReblogs: false,
            mutedNotifications: false
        )
    }
    
    /// Rejecting follow request.
    ///
    /// The endpoint is used to reject a single follow request.
    ///
    /// > Important: Endpoint URL: `/api/v1/follow-requests/:userId/reject`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/follow-requests/7265253398152519681/reject" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "followedBy": false,
    ///     "following": false,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7265253398152519681"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `FollowRequestError.missingSourceUser` if missing source user in database.
    /// - Throws: `FollowRequestError.missingTargetUser` if missing target user in database.
    /// - Throws: `FollowRequestError.missingFollowEntity` if follow entity not exists in local database.
    /// - Throws: `FollowRequestError.missingActivityPubActionId` if Activity Pub action id in follow request is missing.
    /// - Throws: `FollowRequestError.missingPrivateKey` if private key for user not exists in local database.
    func reject(request: Request) async throws -> RelationshipDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let userId = id.toId() else {
            throw Abort(.badRequest)
        }
        
        guard let sourceUser = try await User.query(on: request.db).filter(\.$id == userId).first() else {
            throw FollowRequestError.missingSourceUser(userId)
        }
        
        guard let targetUser = try await User.query(on: request.db).filter(\.$id == authorizationPayloadId).first() else {
            throw FollowRequestError.missingTargetUser(authorizationPayloadId)
        }

        let followsService = request.application.services.followsService
        guard let follow = try await followsService.get(on: request.db, sourceId: userId, targetId: authorizationPayloadId) else {
            throw FollowRequestError.missingFollowEntity(userId, authorizationPayloadId)
        }
        
        if sourceUser.isLocal == false && follow.activityId == nil {
            throw FollowRequestError.missingActivityPubActionId
        }
        
        guard let privateKey = targetUser.privateKey else {
            throw FollowRequestError.missingPrivateKey(targetUser.userName)
        }
        
        // Reject in local database.
        try await followsService.reject(on: request.db, sourceId: userId, targetId: authorizationPayloadId)
        
        // Send information to remote server (for remote accounts) server about rejected follow.
        if sourceUser.isLocal == false {
            try await informRemote(on: request,
                                   approved: false,
                                   requesting: sourceUser.activityPubProfile,
                                   asked: targetUser.activityPubProfile,
                                   inbox: sourceUser.userInbox,
                                   withId: follow.requireID(),
                                   acceptedId: follow.activityId,
                                   privateKey: privateKey)
        }
        
        let relationshipsService = request.application.services.relationshipsService
        let relationships = try await relationshipsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: [userId])
        return relationships.first ?? RelationshipDto(
            userId: id,
            following: false,
            followedBy: false,
            requested: false,
            requestedBy: false,
            mutedStatuses: false,
            mutedReblogs: false,
            mutedNotifications: false
        )
    }
    
    private func informRemote(on request: Request,
                              approved: Bool,
                              requesting: String,
                              asked: String,
                              inbox: String?,
                              withId id: Int64,
                              acceptedId: String?,
                              privateKey: String) async throws {
        guard let inbox, let inboxUrl = URL(string: inbox) else {
            return
        }

        guard let acceptedId else {
            return
        }
        
        let activityPubFollowRespondDto = ActivityPubFollowRespondDto(approved: approved,
                                                                      requesting: requesting,
                                                                      asked: asked,
                                                                      inbox: inboxUrl,
                                                                      id: id,
                                                                      orginalRequestId: acceptedId,
                                                                      privateKey: privateKey)

        try await request
            .queues(.apFollowResponder)
            .dispatch(ActivityPubFollowResponderJob.self, activityPubFollowRespondDto)
    }
}
