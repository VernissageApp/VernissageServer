//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

/// Controls basic operations for User object.
final class UsersController: RouteCollection {

    public static let uri: PathComponent = .constant("users")
    
    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UsersController.uri)
            .grouped(UserAuthenticator())
        
        usersGroup
            .grouped(EventHandlerMiddleware(.usersRead))
            .get(":name", use: read)

        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersUpdate))
            .put(":name", use: update)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersDelete))
            .delete(":name", use: delete)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersFollow))
            .post(":name", "follow", use: follow)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersUnfollow))
            .post(":name", "unfollow", use: unfollow)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.usersFollowers))
            .get(":name", "followers", use: followers)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.usersFollowing))
            .get(":name", "following", use: following)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.usersFollowing))
            .get(":name", "statuses", use: statuses)
    }

    /// User profile.
    func read(request: Request) async throws -> UserDto {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userFromDb = try await usersService.get(on: request.db, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let flexiFields = try await user.$flexiFields.get(on: request.db)
        let userProfile = self.cleanUserProfile(on: request,
                                                user: user,
                                                flexiFields: flexiFields,
                                                userNameFromRequest: userNameNormalized)
        
        return userProfile
    }

    /// Update user data.
    func update(request: Request) async throws -> UserDto {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let flexiFieldService = request.application.services.flexiFieldService
        
        guard usersService.isSignedInUser(on: request, userName: userName) else {
            throw EntityForbiddenError.userForbidden
        }
        
        let userDto = try request.content.decode(UserDto.self)
        try UserDto.validate(content: request)
        
        let user = try await usersService.updateUser(on: request, userDto: userDto, userNameNormalized: request.userNameNormalized)
        let flexiFields = try await flexiFieldService.getFlexiFields(on: request.db, for: user.requireID())
        
        // Enqueue job for flexi field URL validator.
        try await flexiFieldService.dispatchUrlValidator(on: request, flexiFields: flexiFields)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }

    /// Delete user.
    func delete(request: Request) async throws -> HTTPStatus {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        guard usersService.isSignedInUser(on: request, userName: userName) else {
            throw EntityForbiddenError.userForbidden
        }
        
        guard let userFromDb = try await usersService.get(on: request.db, userName: request.userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        // Here we have soft delete function (user is marked as deleted only).
        try await usersService.delete(user: userFromDb, on: request.db)
        
        try await request
            .queues(.userDeleter)
            .dispatch(UserDeleterJob.self, userFromDb.requireID())
        
        return HTTPStatus.ok
    }
    
    func follow(request: Request) async throws -> RelationshipDto {
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()

        guard let followedUser = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let sourceUser = try await User.find(authorizationPayloadId, on: request.db) else {
            throw Abort(.notFound)
        }
        
        // We have to validate thigs for remote user (before we change something in database).
        if followedUser.isLocal == false {
            guard let _ = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
            
            guard let sharedInbox = followedUser.sharedInbox, let _ = URL(string: sharedInbox) else {
                throw ActivityPubError.missingSharedInboxUrl(sourceUser.activityPubProfile)
            }
        }
        
        // Relationship is automatically approved only when user disabled manual aproving and is local.
        let approved = followedUser.isLocal && followedUser.manuallyApprovesFollowers == false
        
        // Save follow in local database.
        let followId = try await followsService.follow(on: request.db,
                                                       sourceId: sourceUser.requireID(),
                                                       targetId: followedUser.requireID(),
                                                       approved: approved,
                                                       activityId: nil)
        
        try await usersService.updateFollowCount(on: request.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: request.db, for: followedUser.requireID())
        
        // Send notification to user about follow.
        let notificationsService = request.application.services.notificationsService
        try await notificationsService.create(type: approved ? .follow : .followRequest,
                                              to: followedUser,
                                              by: sourceUser.requireID(),
                                              statusId: nil,
                                              on: request.db)
        
        // If target user is from remote server, notify remote server about follow.
        if followedUser.isLocal == false {
            guard let privateKey = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
                        
            try await informRemote(on: request,
                                   type: .follow,
                                   source: sourceUser.activityPubProfile,
                                   target: followedUser.activityPubProfile,
                                   sharedInbox: followedUser.sharedInbox,
                                   withId: followId,
                                   privateKey: privateKey)
        }
        
        return try await self.relationship(on: request, sourceId: authorizationPayloadId, targetUser: followedUser)
    }

    func unfollow(request: Request) async throws -> RelationshipDto {
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        let userNameNormalized = userName.deletingPrefix("@").uppercased()

        guard let followedUser = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let sourceUser = try await User.find(authorizationPayloadId, on: request.db) else {
            throw Abort(.notFound)
        }
        
        // We have to validate thigs for remote user (before we change something in database).
        if followedUser.isLocal == false {
            guard let _ = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
            
            guard let sharedInbox = followedUser.sharedInbox, let _ = URL(string: sharedInbox) else {
                throw ActivityPubError.missingSharedInboxUrl(followedUser.activityPubProfile)
            }
        }
        
        // Delete follow from local database.
        let followId = try await followsService.unfollow(on: request.db, sourceId: sourceUser.requireID(), targetId: followedUser.requireID())
        
        // User doesn't follow other user.
        guard let followId else {
            return try await self.relationship(on: request, sourceId: authorizationPayloadId, targetUser: followedUser)
        }
        
        try await usersService.updateFollowCount(on: request.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: request.db, for: followedUser.requireID())
        
        // If target user is from remote server, notify remote server about unfollow (in background job).
        if followedUser.isLocal == false {
            guard let privateKey = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
            
            try await informRemote(on: request,
                                   type: .unfollow,
                                   source: sourceUser.activityPubProfile,
                                   target: followedUser.activityPubProfile,
                                   sharedInbox: followedUser.sharedInbox,
                                   withId: followId,
                                   privateKey: privateKey)
        }

        return try await self.relationship(on: request, sourceId: authorizationPayloadId, targetUser: followedUser)
    }
    
    func followers(request: Request) async throws -> LinkableResultDto<UserDto> {
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService

        let linkableParams = request.linkableParams()
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
                
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        let linkableUsers = try await followsService.follows(on: request, targetId: user.requireID(), onlyApproved: false, linkableParams: linkableParams)
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            let userProfile = self.cleanUserProfile(on: request,
                                                    user: user,
                                                    flexiFields: flexiFields,
                                                    userNameFromRequest: userNameNormalized)
            return userProfile
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }
    
    func following(request: Request) async throws -> LinkableResultDto<UserDto> {
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService

        let linkableParams = request.linkableParams()
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
                
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        let linkableUsers = try await followsService.following(on: request, sourceId: user.requireID(), onlyApproved: false, linkableParams: linkableParams)
        
        let userProfiles = try await linkableUsers.data.parallelMap { user in
            let flexiFields = try await user.$flexiFields.get(on: request.db)
            let userProfile = self.cleanUserProfile(on: request,
                                                    user: user,
                                                    flexiFields: flexiFields,
                                                    userNameFromRequest: userNameNormalized)
            return userProfile
        }
        
        return LinkableResultDto(
            maxId: linkableUsers.maxId,
            minId: linkableUsers.minId,
            data: userProfiles
        )
    }
    
    /// Exposing list of statuses.
    func statuses(request: Request) async throws -> LinkableResultDto<StatusDto> {
        let statusesService = request.application.services.statusesService
        let usersService = request.application.services.usersService

        let linkableParams = request.linkableParams()
        let authorizationPayloadId = request.userId
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let userId = try? user.requireID() else {
            throw EntityNotFoundError.userNotFound
        }
        
        if authorizationPayloadId == userId {
            // For signed in users we have to show all kind of statuses on their own profiles (public/followers/mentioned).
            let linkableStatuses = try await usersService.ownStatuses(for: userId, linkableParams: linkableParams, on: request)
                        
            let statusDtos = await linkableStatuses.data.asyncMap({
                await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
            })
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        } else {
            // For profiles other users we have to show only public statuses.
            let linkableStatuses = try await usersService.publicStatuses(for: userId, linkableParams: linkableParams, on: request)
            
            let statusDtos = await linkableStatuses.data.asyncMap({
                await statusesService.convertToDtos(on: request, status: $0, attachments: $0.attachments)
            })
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        }
    }
    
    private func cleanUserProfile(on request: Request, user: User, flexiFields: [FlexiField], userNameFromRequest: String) -> UserDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        var userDto = UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)

        let userNameFromToken = request.auth.get(UserPayload.self)?.userName
        let isProfileOwner = userNameFromToken?.uppercased() == userNameFromRequest

        if !isProfileOwner {
            userDto.email = nil
            userDto.locale = nil
        }

        return userDto
    }
    
    private func relationship(on request: Request, sourceId: Int64, targetUser: User) async throws -> RelationshipDto {
        let followsService = request.application.services.followsService

        let targetUserId = try targetUser.requireID()
        let relationships = try await followsService.relationships(on: request.db, userId: sourceId, relatedUserIds: [targetUserId])
        return relationships.first ?? RelationshipDto(userId: "\(targetUserId)", following: false, followedBy: false, requested: false, requestedBy: false)
    }
    
    private func informRemote(on request: Request,
                              type: ActivityPubFollowRequestDto.FollowRequestType,
                              source: String,
                              target: String,
                              sharedInbox: String?,
                              withId id: Int64,
                              privateKey: String) async throws {
        guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
            return
        }
        
        let activityPubFollowRequestDto = ActivityPubFollowRequestDto(type: type,
                                                                      source: source,
                                                                      target: target,
                                                                      sharedInbox: sharedInboxUrl,
                                                                      id: id,
                                                                      privateKey: privateKey)

        try await request
            .queues(.apFollowRequester)
            .dispatch(ActivityPubFollowRequesterJob.self, activityPubFollowRequestDto)
    }
}
