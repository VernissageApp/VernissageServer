//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

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
    }

    /// User profile.
    func read(request: Request) async throws -> UserDto {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let userNameNormalized = userName.deletingPrefix("@").uppercased()
        let userFromDb = try await usersService.get(on: request, userName: userNameNormalized)

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
        let flexiFields = try await flexiFieldService.getFlexiFields(on: request, for: user.requireID())
        
        // Enqueue job for flexi field URL validator.
        try await flexiFieldService.dispatchUrlValidator(on: request, flexiFields: flexiFields)
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
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

    private func cleanUserProfile(on request: Request, user: User, flexiFields: [FlexiField], userNameFromRequest: String) -> UserDto {
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
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
