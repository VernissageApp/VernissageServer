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
        let userNameNormalized = userName.replacingOccurrences(of: "@", with: "").uppercased()
        let userFromDb = try await usersService.get(on: request, userName: userNameNormalized)

        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let userProfile = self.cleanUserProfile(on: request,
                                                user: user,
                                                userNameFromRequest: userNameNormalized)
        
        return userProfile
    }

    /// Update user data.
    func update(request: Request) async throws -> UserDto {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let userNameNormalized = userName.replacingOccurrences(of: "@", with: "").uppercased()
        let userNameFromToken = request.auth.get(UserPayload.self)?.userName

        let isProfileOwner = userNameFromToken?.uppercased() == userNameNormalized
        guard isProfileOwner else {
            throw EntityForbiddenError.userForbidden
        }
        
        let userDto = try request.content.decode(UserDto.self)
        try UserDto.validate(content: request)
        
        let usersService = request.application.services.usersService
        let user = try await usersService.updateUser(on: request, userDto: userDto, userNameNormalized: userNameNormalized)
        
        return UserDto(from: user)
    }

    /// Delete user.
    func delete(request: Request) async throws -> HTTPStatus {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let userNameNormalized = userName.replacingOccurrences(of: "@", with: "").uppercased()
        let userNameFromToken = request.auth.get(UserPayload.self)?.userName

        let isProfileOwner = userNameFromToken?.uppercased() == userNameNormalized
        guard isProfileOwner else {
            throw EntityForbiddenError.userForbidden
        }
        
        let usersService = request.application.services.usersService
        try await usersService.deleteUser(on: request, userNameNormalized: userNameNormalized)
        
        return HTTPStatus.ok
    }

    private func cleanUserProfile(on request: Request, user: User, userNameFromRequest: String) -> UserDto {
        var userDto = UserDto(from: user)

        let userNameFromToken = request.auth.get(UserPayload.self)?.userName
        let isProfileOwner = userNameFromToken?.uppercased() == userNameFromRequest

        if !isProfileOwner {
            userDto.email = nil
            userDto.birthDate = nil
        }

        return userDto
    }
}
