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
            .grouped("api")
            .grouped("v1")
            .grouped(UserRolesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
        
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

        guard let userId = userRoleDto.userId.toId() else {
            throw Abort(.badRequest)
        }
        
        let user = try await User.find(userId, on: request.db)
        guard let user = user else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.find(userRoleDto.roleId.toId(), on: request.db)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.attach(role, on: request.db)

        return HTTPStatus.ok
    }

    /// Disconnects role and user.
    func disconnect(request: Request) async throws -> HTTPResponseStatus {
        let userRoleDto = try request.content.decode(UserRoleDto.self)

        guard let userId = userRoleDto.userId.toId() else {
            throw Abort(.badRequest)
        }
        
        let user = try await User.find(userId, on: request.db)
        guard let user = user else {
            throw EntityNotFoundError.userNotFound
        }
        
        let role = try await Role.find(userRoleDto.roleId.toId(), on: request.db)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }

        try await user.$roles.detach(role, on: request.db)

        return HTTPStatus.ok
    }
}
