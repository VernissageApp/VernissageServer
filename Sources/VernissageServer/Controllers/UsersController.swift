//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension UsersController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("users")
    
    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UsersController.uri)
            .grouped(UserAuthenticator())

        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.usersList))
            .get(use: list)
        
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
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersMute))
            .post(":name", "mute", use: mute)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(EventHandlerMiddleware(.usersUnmute))
            .post(":name", "unmute", use: unmute)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.usersEnable))
            .post(":name", "enable", use: enable)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.usersDisable))
            .post(":name", "disable", use: disable)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(EventHandlerMiddleware(.userRolesConnect))
            .post(":name", "connect", ":role", use: connect)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
            .grouped(EventHandlerMiddleware(.userRolesDisconnect))
            .post(":name", "disconnect", ":role", use: disconnect)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.userApprove))
            .post(":name", "approve", use: approve)
        
        usersGroup
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsModeratorMiddleware())
            .grouped(EventHandlerMiddleware(.userApprove))
            .post(":name", "reject", use: reject)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.usersStatuses))
            .get(":name", "statuses", use: statuses)
    }
}

/// Operations on users.
///
/// The controller supports multiple operations to manage users.
/// It allows updating/deleting users, following, muting, etc.
///
/// > Important: Base controller URL: `/api/v1/users`.
final class UsersController {

    /// List of users.
    ///
    /// The endpoint returns a list of all users added to the system.
    /// Only administrators and moderators have access to the list.
    ///
    /// Optional query params:
    /// - `page` - number of page to return
    /// - `size` - limit amount of returned entities on one page (default: 10)
    ///
    /// > Important: Endpoint URL: `/api/v1/users`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/09267580898c4d3abfc5871bbdb4483e.jpeg",
    ///             "bio": "<p>Landscape, nature and fine-art photographer</p>",
    ///             "bioHtml": "<p>Landscape, nature and fine-art photographer</p>",
    ///             "createdAt": "2023-08-16T15:13:08.607Z",
    ///             "fields": [],
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "headerUrl": "https://example.com/700049efc6c04068a3634317e1f95e32.jpg",
    ///             "id": "7267938074834522113",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:23.479Z",
    ///             "userName": "johndoe@example.com"
    ///         },
    ///         {
    ///             "account": "lindadoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/lindadoe",
    ///             "avatarUrl": "https://example.com/44debf8889d74b5a9be651f575a3651c.jpg",
    ///             "bio": "<p>Landscape, nature and street photographer</p>",
    ///             "bioHtml": "<p>Landscape, nature and street photographer</p>",
    ///             "createdAt": "2024-02-07T10:25:36.538Z",
    ///             "fields": [],
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "id": "7332804261530576897",
    ///             "isLocal": false,
    ///             "name": "Linda Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-07T10:25:36.538Z",
    ///             "userName": "lindadoe@example.com"
    ///         }
    ///     ],
    ///     "page": 1,
    ///     "size": 10,
    ///     "total": 176
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of paginable users.
    func list(request: Request) async throws -> PaginableResultDto<UserDto> {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let page: Int = request.query["page"] ?? 0
        let size: Int = request.query["size"] ?? 10
        
        let usersFromDatabase = try await User.query(on: request.db)
            .with(\.$flexiFields)
            .with(\.$roles)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: size))
        
        let userDtos = await usersFromDatabase.items.asyncMap({
            var userDto = UserDto(from: $0, flexiFields: $0.flexiFields, roles: $0.roles, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
            userDto.email = $0.email
            userDto.emailWasConfirmed = $0.emailWasConfirmed
            userDto.locale = $0.locale
            userDto.isBlocked = $0.isBlocked
            userDto.isApproved = $0.isApproved
            
            return userDto
        })
        
        return PaginableResultDto(
            data: userDtos,
            page: usersFromDatabase.metadata.page,
            size: usersFromDatabase.metadata.per,
            total: usersFromDatabase.metadata.total
        )
    }
    
    /// User profile.
    ///
    /// The endpoint returns data about the user. This is a public endpoint
    /// that can also be accessed by non-logged-in users.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "account": "johndoe@example.com",
    ///     "activityPubProfile": "https://example.com/users/johndoe",
    ///     "avatarUrl": "https://example.com/09267580898c4d3abfc5871bbdb4483e.jpeg",
    ///     "bio": "<p>Landscape, nature and fine-art photographer</p>",
    ///     "bioHtml": "<p>Landscape, nature and fine-art photographer</p>",
    ///     "createdAt": "2023-08-16T15:13:08.607Z",
    ///     "fields": [],
    ///     "followersCount": 0,
    ///     "followingCount": 0,
    ///     "headerUrl": "https://example.com/700049efc6c04068a3634317e1f95e32.jpg",
    ///     "id": "7267938074834522113",
    ///     "isLocal": false,
    ///     "name": "John Doe",
    ///     "statusesCount": 0,
    ///     "updatedAt": "2024-02-09T05:12:23.479Z",
    ///     "userName": "johndoe@example.com"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Public user's profile.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
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
        let userProfile = self.getUserProfile(on: request,
                                                user: user,
                                                flexiFields: flexiFields,
                                                userNameFromRequest: userNameNormalized)
        
        return userProfile
    }

    /// Update user data.
    ///
    /// The endpoint allows to update your user data. Only the user who owns the profile
    /// can change its data. In addition to the basic information, it is also possible to change
    /// additional fields. After editing a field, its status is changed to unverified. If the value
    /// of the field is a URL, then the server downloads the content of the page and looks for
    /// a link to the user's profile (the link must contain the `rel="me"` element), if it finds then
    /// the field is considered verified.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe" \
    /// -X PUT \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "account": "johndoe@example.com",
    ///     "activityPubProfile": "https://example.com/actors/johndoe",
    ///     "avatarUrl": "https://example.com/039ebf33d1664d5d849574d0e7191354.jpg",
    ///     "bio": "#iOS/#dotNET developer",
    ///     "bioHtml": "<p><a href=\"https://example.com/tags/iOS\">#iOS</a>/<a href=\"https://example.com/tags/dotNET\">#dotNET</a> developer</p>",
    ///     "createdAt": "2023-07-20T17:25:13.255Z",
    ///     "email": "johndoe@example.com",
    ///     "emailWasConfirmed": true,
    ///     "fields": [
    ///         {
    ///             "id": "7258237663562680321",
    ///             "isVerified": true,
    ///             "key": "MASTODON",
    ///             "value": "https://mastodon.social/@johndoe",
    ///             "valueHtml": "<a href=\"https://mastodon.social/@johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">https://mastodon.social/@johndoe</a>"
    ///         },
    ///         {
    ///             "id": "7258237663562694657",
    ///             "isVerified": true,
    ///             "key": "GITHUB",
    ///             "value": "https://github.com/johndoe",
    ///             "valueHtml": "<a href=\"https://github.com/johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">https://github.com/johndoe</a>"
    ///         }
    ///     ],
    ///     "followersCount": 7,
    ///     "followingCount": 9,
    ///     "headerUrl": "https://example.com/2ef4a0f69d0e410ba002df2212e2b63c.jpg",
    ///     "id": "7257953010311411713",
    ///     "isLocal": true,
    ///     "locale": "en_US",
    ///     "name": "John Doe",
    ///     "statusesCount": 12,
    ///     "updatedAt": "2024-02-10T09:32:24.860Z",
    ///     "userName": "johndoe"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "account": "johndoe@example.com",
    ///     "activityPubProfile": "https://example.com/actors/johndoe",
    ///     "avatarUrl": "https://example.com/039ebf33d1664d5d849574d0e7191354.jpg",
    ///     "bio": "#iOS/#dotNET developer",
    ///     "bioHtml": "<p><a href=\"https://example.com/tags/iOS\">#iOS</a>/<a href=\"https://example.com/tags/dotNET\">#dotNET</a> developer</p>",
    ///     "createdAt": "2023-07-20T17:25:13.255Z",
    ///     "email": "johndoe@example.com",
    ///     "emailWasConfirmed": true,
    ///     "fields": [
    ///         {
    ///             "id": "7258237663562680321",
    ///             "isVerified": false,
    ///             "key": "MASTODON",
    ///             "value": "https://mastodon.social/@johndoe",
    ///             "valueHtml": "<a href=\"https://mastodon.social/@johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">https://mastodon.social/@johndoe</a>"
    ///         },
    ///         {
    ///             "id": "7258237663562694657",
    ///             "isVerified": false,
    ///             "key": "GITHUB",
    ///             "value": "https://github.com/johndoe",
    ///             "valueHtml": "<a href=\"https://github.com/johndoe\" rel=\"me nofollow noopener noreferrer\" class=\"url\" target=\"_blank\">https://github.com/johndoe</a>"
    ///         }
    ///     ],
    ///     "followersCount": 7,
    ///     "followingCount": 9,
    ///     "headerUrl": "https://example.com/2ef4a0f69d0e410ba002df2212e2b63c.jpg",
    ///     "id": "7257953010311411713",
    ///     "isLocal": true,
    ///     "locale": "en_US",
    ///     "name": "John Doe",
    ///     "statusesCount": 12,
    ///     "updatedAt": "2024-02-10T09:32:36.967Z",
    ///     "userName": "johndoe"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Public user's profile.
    ///
    /// - Throws: `EntityForbiddenError.userForbidden` if access to specified user is forbidden.
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
        
        var userDtoAfterUpdate = UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
        userDtoAfterUpdate.email = user.email
        userDtoAfterUpdate.emailWasConfirmed = user.emailWasConfirmed
        userDtoAfterUpdate.locale = user.locale
        
        return userDtoAfterUpdate
    }

    /// Delete user.
    ///
    /// Checkpoint allows you to delete a user profile. Deletion is possible only
    /// by the profile owner and the moderator and administrator.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityForbiddenError.userForbidden` if access to specified user is forbidden.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let usersService = request.application.services.usersService

        guard let userFromDb = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard userFromDb.id == authorizationPayloadId || request.isModerator || request.isAdministrator else {
            throw EntityForbiddenError.userForbidden
        }
        
        // Here we have soft delete function (user is marked as deleted only).
        try await usersService.delete(user: userFromDb, force: false, on: request.db)
        
        try await request
            .queues(.userDeleter)
            .dispatch(UserDeleterJob.self, userFromDb.requireID())
        
        return HTTPStatus.ok
    }
    
    /// Follow user.
    ///
    /// Checkpoint allows you to follow other user from the system.
    /// User can follow local user or user from remote instance.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/follow`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/follow" \
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
    ///     "userId": "7260098629943709697"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
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

    /// Unfollow user.
    ///
    /// Checkpoint allows you to unfollow other user from the system.
    /// User can unfollow local user or user from remote instance.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/unfollow`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/unfollow" \
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
    ///     "following": false,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7260098629943709697"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
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
    
    /// List of followers.
    ///
    /// This endpoint returns information about followers.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/followers`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@lindadoe/followers" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/cd743f07793747daa7d9aa7662b78f7a.jpeg",
    ///             "bio": "<p>This is a bio.</p>",
    ///             "bioHtml": "<p><This is a bio.</p>",
    ///             "createdAt": "2023-07-27T15:39:47.627Z",
    ///             "fields": [],
    ///             "followersCount": 1,
    ///             "followingCount": 1,
    ///             "headerUrl": "https://example.com/ab01b3185a82430788016f4072d5d81b.jpg",
    ///             "id": "7260522736489424897",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:22.711Z",
    ///             "userName": "johndoe@example.com"
    ///         }
    ///     ],
    ///     "maxId": "7317208934634969089",
    ///     "minId": "7317208934634969089"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
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
            let userProfile = self.getUserProfile(on: request,
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
    
    /// List of following.
    ///
    /// This endpoint returns information about following users.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/following`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@lindadoe/following" \
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
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/users/johndoe",
    ///             "avatarUrl": "https://example.com/cd743f07793747daa7d9aa7662b78f7a.jpeg",
    ///             "bio": "<p>This is a bio.</p>",
    ///             "bioHtml": "<p><This is a bio.</p>",
    ///             "createdAt": "2023-07-27T15:39:47.627Z",
    ///             "fields": [],
    ///             "followersCount": 1,
    ///             "followingCount": 1,
    ///             "headerUrl": "https://example.com/ab01b3185a82430788016f4072d5d81b.jpg",
    ///             "id": "7260522736489424897",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T05:12:22.711Z",
    ///             "userName": "johndoe@example.com"
    ///         }
    ///     ],
    ///     "maxId": "7317208934634969089",
    ///     "minId": "7317208934634969089"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable users.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
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
            let userProfile = self.getUserProfile(on: request,
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
    
    /// Mute specific user.
    ///
    /// The endpoint allows you to wipe out another user.
    /// It is possible to leak statuses, reblogs and notifications.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/mute`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/mute" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "muteStatuses": true,
    ///     "muteReblogs": true,
    ///     "muteNotifications": true,
    ///     "muteEnd": "2024-02-28T23:00:00.000Z"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "followedBy": true,
    ///     "following": true,
    ///     "mutedNotifications": true,
    ///     "mutedReblogs": true,
    ///     "mutedStatuses": true,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7260098629943709697"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint ``UserMuteRequestDto``.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func mute(request: Request) async throws -> RelationshipDto {
        let usersService = request.application.services.usersService
        let userMutesService = request.application.services.userMutesService
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let userMuteRequestDto = try request.content.decode(UserMuteRequestDto.self)
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        
        guard let mutedUser = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        _ = try await userMutesService.mute(
            on: request.db,
            userId: authorizationPayloadId,
            mutedUserId: mutedUser.requireID(),
            muteStatuses: userMuteRequestDto.muteStatuses,
            muteReblogs: userMuteRequestDto.muteReblogs,
            muteNotifications: userMuteRequestDto.muteNotifications,
            muteEnd: userMuteRequestDto.muteEnd
        )
        
        return try await self.relationship(on: request, sourceId: authorizationPayloadId, targetUser: mutedUser)
    }
    
    /// Unmute specific user.
    ///
    /// The endpoint allows you to disable user muting.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/unmute`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/unmute" \
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
    ///     "following": false,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7260098629943709697"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about relationship.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func unmute(request: Request) async throws -> RelationshipDto {
        let usersService = request.application.services.usersService
        let userMutesService = request.application.services.userMutesService
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        
        guard let unmutedUser = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        try await userMutesService.unmute(on: request.db, userId: authorizationPayloadId, mutedUserId: unmutedUser.requireID())
        return try await self.relationship(on: request, sourceId: authorizationPayloadId, targetUser: unmutedUser)
    }
    
    /// Enable specific user.
    ///
    /// An endpoint to unlock a user's account.
    /// Moderators have access to the endpoint.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/enable`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/enable" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func enable(request: Request) async throws -> HTTPStatus {
        let usersService = request.application.services.usersService
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        user.isBlocked = false
        try await user.save(on: request.db)
                
        return HTTPStatus.ok
    }
    
    /// Disable specific user.
    ///
    /// An endpoint to lock a user's account.
    /// Moderators have access to the endpoint.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/disable`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/disable" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func disable(request: Request) async throws -> HTTPStatus {
        let usersService = request.application.services.usersService
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        user.isBlocked = true
        try await user.save(on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Connect role to the user.
    ///
    /// The endpoint allows administrator to connect user to specific role.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/connect/:roleName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/connect/moderator" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `EntityNotFoundError.roleNotFound` if role not exists.
    func connect(request: Request) async throws -> HTTPResponseStatus {
        let usersService = request.application.services.usersService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let roleCode = request.parameters.get("role") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.query(on: request.db)
            .filter(\.$code == roleCode)
            .first()

        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.attach(role, on: request.db)

        return HTTPStatus.ok
    }

    /// Disconnects role and user.
    ///
    /// The endpoint allows administrator to disconnects user to specific role.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/disconnect/:roleName`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/disconnect/moderator" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `EntityNotFoundError.roleNotFound` if role not exists.
    func disconnect(request: Request) async throws -> HTTPResponseStatus {
        let usersService = request.application.services.usersService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        guard let roleCode = request.parameters.get("role") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.query(on: request.db)
            .filter(\.$code == roleCode)
            .first()

        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.detach(role, on: request.db)

        return HTTPStatus.ok
    }
    
    /// Approve user.
    ///
    /// If registration that requires acceptance is enabled this endpoint
    /// allows you to accept such a request.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/approve`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/approve" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    func approve(request: Request) async throws -> HTTPResponseStatus {
        let usersService = request.application.services.usersService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        if user.isApproved == false {
            user.isApproved = true
            try await user.save(on: request.db)
        }

        return HTTPStatus.ok
    }
    
    /// Reject user.
    ///
    /// If registration that requires acceptance is enabled this endpoint
    /// allows you to reject such a request.
    ///
    /// > Important: Endpoint URL: `/api/v1/users/:userName/reject`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/reject" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `UserError.userAlreadyApproved` if user account is already apporoved.
    func reject(request: Request) async throws -> HTTPResponseStatus {
        let usersService = request.application.services.usersService

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        guard let user = try await usersService.get(on: request.db, userName: userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard user.isApproved == false else {
            throw UserError.userAlreadyApproved
        }

        // Here we can delete user completly from database (since he didn't add anything to database).
        try await usersService.delete(user: user, force: true, on: request.db)
        
        return HTTPStatus.ok
    }
    
    /// Exposing list of statuses.
    ///
    /// An endpoint that returns a list of statuses added to the system by a given user.
    ///
    /// Optional query params:
    /// - `minId` - return only newest entities
    /// - `maxId` - return only oldest entities
    /// - `sinceId` - return latest entites since entity
    /// - `limit` - limit amount of returned entities (default: 40)
    ///
    /// > Important: Endpoint URL: `/api/v1/users/@johndoe/statuses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/users/@johndoe/statuses" \
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
    ///             "application": "Vernissage 1.0.0-alpha1",
    ///             "attachments": [
    ///                 {
    ///                     "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///                     "description": "Image",
    ///                     "id": "7333853122610388993",
    ///                     "license": {
    ///                         "code": "CC BY-SA",
    ///                         "id": "7310942225159069697",
    ///                         "name": "Attribution-ShareAlike",
    ///                         "url": "https://creativecommons.org/licenses/by-sa/4.0/"
    ///                     },
    ///                     "location": {
    ///                         "country": {
    ///                             "code": "PL",
    ///                             "id": "7257110629787191297",
    ///                             "name": "Poland"
    ///                         },
    ///                         "id": "7257110934739898369",
    ///                         "latitude": "51,1",
    ///                         "longitude": "17,03333",
    ///                         "name": "Wrocław"
    ///                     },
    ///                     "metadata": {
    ///                         "exif": {
    ///                             "createDate": "2022-10-20T14:24:51.037+02:00",
    ///                             "exposureTime": "1/500",
    ///                             "fNumber": "f/8",
    ///                             "focalLenIn35mmFilm": "85",
    ///                             "lens": "Zeiss Batis 1.8/85",
    ///                             "make": "SONY",
    ///                             "model": "ILCE-7M4",
    ///                             "photographicSensitivity": "100"
    ///                         }
    ///                     },
    ///                     "originalFile": {
    ///                         "aspect": 1.4998169168802635,
    ///                         "height": 2731,
    ///                         "url": "https://example.com/088207bf34c749b0ab0eb95c98cc1dbf.jpg",
    ///                         "width": 4096
    ///                     },
    ///                     "smallFile": {
    ///                         "aspect": 1.5009380863039399,
    ///                         "height": 533,
    ///                         "url": "https://example.com/4aff6ec34865483ab2e6b3b145826e46.jpg",
    ///                         "width": 800
    ///                     }
    ///                 }
    ///             ],
    ///             "bookmarked": false,
    ///             "commentsDisabled": false,
    ///             "contentWarning": "This photo contains nudity.",
    ///             "createdAt": "2024-02-10T06:16:39.852Z",
    ///             "favourited": false,
    ///             "favouritesCount": 0,
    ///             "featured": false,
    ///             "id": "7333853122610761729",
    ///             "isLocal": true,
    ///             "note": "Status text",
    ///             "noteHtml": "<p>Status text</p>",
    ///             "reblogged": false,
    ///             "reblogsCount": 0,
    ///             "repliesCount": 0,
    ///             "sensitive": true,
    ///             "tags": [],
    ///             "updatedAt": "2024-02-10T06:16:39.852Z",
    ///             "user": { ... },
    ///             "visibility": "public"
    ///         }
    ///     ],
    ///     "maxId": "7333853122610761729",
    ///     "minId": "7333853122610761729"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of linkable statuses.
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
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        } else {
            // For profiles other users we have to show only public statuses.
            let linkableStatuses = try await usersService.publicStatuses(for: userId, linkableParams: linkableParams, on: request)
            let statusDtos = await statusesService.convertToDtos(on: request, statuses: linkableStatuses.data)
            
            return LinkableResultDto(
                maxId: linkableStatuses.maxId,
                minId: linkableStatuses.minId,
                data: statusDtos
            )
        }
    }
    
    private func getUserProfile(on request: Request, user: User, flexiFields: [FlexiField], userNameFromRequest: String) -> UserDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        var userDto = UserDto(from: user, flexiFields: flexiFields, baseStoragePath: baseStoragePath, baseAddress: baseAddress)

        let userNameFromToken = request.auth.get(UserPayload.self)?.userName
        let isProfileOwner = userNameFromToken?.uppercased() == userNameFromRequest

        if isProfileOwner {
            userDto.email = user.email
            userDto.locale = user.locale
            userDto.emailWasConfirmed = user.emailWasConfirmed
        }

        return userDto
    }
    
    private func relationship(on request: Request, sourceId: Int64, targetUser: User) async throws -> RelationshipDto {
        let targetUserId = try targetUser.requireID()
        let relationshipsService = request.application.services.relationshipsService
        let relationships = try await relationshipsService.relationships(on: request.db, userId: sourceId, relatedUserIds: [targetUserId])

        return relationships.first ?? RelationshipDto(
            userId: "\(targetUserId)",
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