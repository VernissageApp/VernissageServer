//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Connect/disconnect user with role.
final class UserRolesController: RouteCollection {

    public static let uri: PathComponent = .constant("user-roles")
    
    func boot(routes: RoutesBuilder) throws {
        let userRolesGroup = routes
            .grouped(UserRolesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsSuperUserMiddleware())
        
        userRolesGroup
            .grouped(EventHandlerMiddleware(.userRolesConnect))
            .post("connect", use: connect)
        
        userRolesGroup
            .grouped(EventHandlerMiddleware(.userRolesDisconnect))
            .post("disconnect", use: disconnect)
    }
    
    /// Connect role to the user.
    func connect(request: Request) async throws -> HTTPResponseStatus {
        let userRoleDto = try request.content.decode(UserRoleDto.self)

        let user = try await User.find(userRoleDto.userId, on: request.db)
        guard let user = user else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.find(userRoleDto.roleId, on: request.db)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.attach(role, on: request.db)

        return HTTPStatus.ok
    }

    /// Disconnects role and user.
    func disconnect(request: Request) async throws -> HTTPResponseStatus {
        let userRoleDto = try request.content.decode(UserRoleDto.self)

        let user = try await User.find(userRoleDto.userId, on: request.db)
        guard let user = user else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.find(userRoleDto.roleId, on: request.db)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.detach(role, on: request.db)

        return HTTPStatus.ok
    }
}
