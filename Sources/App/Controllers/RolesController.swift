//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controller for managing system roles.
final class RolesController: RouteCollection {

    public static let uri: PathComponent = .constant("roles")
    
    func boot(routes: RoutesBuilder) throws {
        let rolesGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(RolesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
            .grouped(UserPayload.guardIsAdministratorMiddleware())
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesList))
            .get(use: list)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesRead))
            .get(":id", use: read)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesUpdate))
            .put(":id", use: update)
    }

    /// Get all roles.
    func list(request: Request) async throws -> [RoleDto] {
        let roles = try await Role.query(on: request.db).all()
        return roles.map { role in RoleDto(from: role) }
    }

    /// Get specific role.
    func read(request: Request) async throws -> RoleDto {
        guard let roleIdString = request.parameters.get("id", as: String.self) else {
            throw RoleError.incorrectRoleId
        }
        
        guard let roleId = roleIdString.toId() else {
            throw RoleError.incorrectRoleId
        }

        let role = try await self.getRoleById(on: request, roleId: roleId)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }
        
        return RoleDto(from: role)
    }

    /// Update specific role.
    func update(request: Request) async throws -> RoleDto {
        guard let roleIdString = request.parameters.get("id", as: String.self) else {
            throw RoleError.incorrectRoleId
        }
        
        guard let roleId = roleIdString.toId() else {
            throw RoleError.incorrectRoleId
        }
        
        let roleDto = try request.content.decode(RoleDto.self)
        try RoleDto.validate(content: request)

        let role = try await self.getRoleById(on: request, roleId: roleId)
        guard let role = role else {
            throw EntityNotFoundError.roleNotFound
        }
        
        try await self.updateRole(on: request, from: roleDto, to: role)
        return RoleDto(from: role)
    }

    private func getRoleById(on request: Request, roleId: Int64) async throws -> Role? {
        let role = try await Role.find(roleId, on: request.db)
        return role
    }

    private func updateRole(on request: Request, from roleDto: RoleDto, to role: Role) async throws {
        role.title = roleDto.title
        role.description = roleDto.description
        role.isDefault = roleDto.isDefault

        try await role.update(on: request.db)
    }
}
