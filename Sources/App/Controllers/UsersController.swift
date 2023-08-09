//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
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
        return UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath)
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
        
        try await usersService.deleteUser(on: request, userNameNormalized: request.userNameNormalized)
        
        // TODO: Send information to the fediverse about deleted account.
        
        return HTTPStatus.ok
    }
    
    func follow(request: Request) async throws -> HTTPStatus {
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
        
        // Save follow in local database.
        let followId = try await followsService.follow(on: request.db, sourceId: sourceUser.requireID(), targetId: followedUser.requireID(), approved: true)
        
        try await usersService.updateFollowCount(on: request.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: request.db, for: followedUser.requireID())
        
        // If target user is from remote server, notify remote server about follow.
        if followedUser.isLocal == false {
            guard let privateKey = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
            
            guard let sharedInbox = followedUser.sharedInbox, let sharedInbox = URL(string: sharedInbox) else {
                throw ActivityPubError.missingSharedInboxUrl(sourceUser.activityPubProfile)
            }
            
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: "(Vernissage/1.0.0)", host: sharedInbox.host)
            
            request.logger.info("Sending follow request to remote instance (source: '\(sourceUser.activityPubProfile)', target: '\(followedUser.activityPubProfile)').")
            try await activityPubClient.follow(followedUser.activityPubProfile, by: sourceUser.activityPubProfile, on: sharedInbox, withId: followId)
        }
        
        return HTTPStatus.ok
    }

    func unfollow(request: Request) async throws -> HTTPStatus {
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
        
        // Delete follow from local database.
        let followId = try await followsService.unfollow(on: request.db, sourceId: sourceUser.requireID(), targetId: followedUser.requireID())
        
        // User doesn't follow other user.
        guard let followId else {
            return HTTPStatus.ok
        }
        
        try await usersService.updateFollowCount(on: request.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: request.db, for: followedUser.requireID())
        
        // If target user is from remote server, notify remote server about unfollow.
        if followedUser.isLocal == false {
            guard let privateKey = sourceUser.privateKey else {
                throw ActivityPubError.privateKeyNotExists(sourceUser.activityPubProfile)
            }
            
            guard let sharedInbox = followedUser.sharedInbox, let sharedInbox = URL(string: sharedInbox) else {
                throw ActivityPubError.missingSharedInboxUrl(sourceUser.activityPubProfile)
            }
            
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: "(Vernissage/1.0.0)", host: sharedInbox.host)
            
            request.logger.info("Sending unfollow request to remote instance (source: '\(sourceUser.activityPubProfile)', target: '\(followedUser.activityPubProfile)').")
            try await activityPubClient.unfollow(followedUser.activityPubProfile, by: sourceUser.activityPubProfile, on: sharedInbox, withId: followId)
        }

        return HTTPStatus.ok
    }
    
    private func cleanUserProfile(on request: Request, user: User, flexiFields: [FlexiField], userNameFromRequest: String) -> UserDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        var userDto = UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath)

        let userNameFromToken = request.auth.get(UserPayload.self)?.userName
        let isProfileOwner = userNameFromToken?.uppercased() == userNameFromRequest

        if !isProfileOwner {
            userDto.email = nil
            userDto.locale = nil
        }

        return userDto
    }
}
