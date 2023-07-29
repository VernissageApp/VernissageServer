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
            .grouped(UserPayload.guardIsSuperUserMiddleware())
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesCreate))
            .post(use: create)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesList))
            .get(use: list)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesRead))
            .get(":id", use: read)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesUpdate))
            .put(":id", use: update)
        
        rolesGroup
            .grouped(EventHandlerMiddleware(.rolesDelete))
            .delete(":id", use: delete)
    }

    /// Create new role.
    func create(request: Request) async throws -> Response {
        let rolesService = request.application.services.rolesService
        let roleDto = try request.content.decode(RoleDto.self)
        try RoleDto.validate(content: request)

        try await rolesService.validateCode(on: request.db, code: roleDto.code, roleId: nil)
        let role = try await self.createRole(on: request, roleDto: roleDto)

        let response = try await self.createNewRoleResponse(on: request, role: role)
        return response
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
        let rolesService = request.application.services.rolesService

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
        
        try await rolesService.validateCode(on: request.db, code: roleDto.code, roleId: role.id)
        try await self.updateRole(on: request, from: roleDto, to: role)

        return RoleDto(from: role)
    }

    /// Delete specific role.
    func delete(request: Request) async throws -> HTTPStatus {
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
        
        try await role.delete(on: request.db)

        return HTTPStatus.ok
    }

    private func createRole(on request: Request, roleDto: RoleDto) async throws -> Role {
        let role = Role(from: roleDto)
        try await role.save(on: request.db)
        return role
    }

    private func createNewRoleResponse(on request: Request, role: Role) async throws -> Response {
        let createdRoleDto = RoleDto(from: role)

        let response = try await createdRoleDto.encodeResponse(for: request)
        response.headers.replaceOrAdd(name: .location, value: "/\(RolesController.uri)/\(role.stringId() ?? "")")
        response.status = .created

        return response
    }

    private func getRoleById(on request: Request, roleId: Int64) async throws -> Role? {
        let role = try await Role.find(roleId, on: request.db)
        return role
    }

    private func updateRole(on request: Request, from roleDto: RoleDto, to role: Role) async throws {
        role.title = roleDto.title
        role.code = roleDto.code
        role.description = roleDto.description
        role.hasSuperPrivileges = roleDto.hasSuperPrivileges
        role.isDefault = roleDto.isDefault

        try await role.update(on: request.db)
    }
}
