//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class FollowRequestsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("follow-requests")
    
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
            .grouped(EventHandlerMiddleware(.followRequestApprove))
            .post(":id", "approve", use: approve)
        
        relationshipsGroup
            .grouped(EventHandlerMiddleware(.followRequestReject))
            .post(":id", "reject", use: reject)
    }

    /// List of requests to approve.
    func list(request: Request) async throws -> LinkableResultDto<RelationshipDto> {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
                
        let linkableParams = request.linkableParams()
        let followsService = request.application.services.followsService
        let linkableResult = try await followsService.toApprove(on: request.db, userId: authorizationPayloadId, linkableParams: linkableParams)
        
        return LinkableResultDto(basedOn: linkableResult)
    }
    
    /// Approving follow request.
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
        
        let relationships = try await followsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: [userId])
        return relationships.first ?? RelationshipDto(userId: id, following: false, followedBy: false, requested: false, requestedBy: false)
    }
    
    /// Rejecting follow request.
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
        
        let relationships = try await followsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: [userId])
        return relationships.first ?? RelationshipDto(userId: id, following: false, followedBy: false, requested: false, requestedBy: false)
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
