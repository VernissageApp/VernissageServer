//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension RolesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("roles")
    
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
}

/// Controller for managing system roles.
///
/// Controller, through which it is possible to manage user roles in the system.
/// By default, there are three roles: `Administrator`, `Moderator` and `Member`.
///
/// > Important: Base controller URL: `/api/v1/roles`.
final class RolesController {

    /// Get all roles.
    ///
    /// The endpoint through which it is possible to download a list of all roles in the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/roles`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/roles" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [
    ///     {
    ///         "code": "administrator",
    ///         "description": "Users have access to whole system.",
    ///         "id": "7250729777261213697",
    ///         "isDefault": false,
    ///         "title": "Administrator"
    ///     },
    ///     {
    ///         "code": "moderator",
    ///         "description": "Users have access to content moderation (approve users/block users etc.).",
    ///         "id": "7250729777261215745",
    ///         "isDefault": false,
    ///         "title": "Moderator"
    ///     },
    ///     {
    ///         "code": "member",
    ///         "description": "Users have access to public part of system.",
    ///         "id": "7250729777261217793",
    ///         "isDefault": true,
    ///         "title": "Member"
    ///     }
    /// ]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of roles.
    func list(request: Request) async throws -> [RoleDto] {
        let roles = try await Role.query(on: request.db).all()
        return roles.map { role in RoleDto(from: role) }
    }

    /// Get specific role.
    ///
    /// The endpoint through which it is possible to download specific role from the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/roles/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/roles/7250729777261217793" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "member",
    ///     "description": "Users have access to public part of system.",
    ///     "id": "7250729777261217793",
    ///     "isDefault": true,
    ///     "title": "Member"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about role.
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
    ///
    /// Endpoint, used to change the basic information of the role.
    ///
    /// > Important: Endpoint URL: `/api/v1/roles/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/roles/7250729777261217793" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "code": "member",
    ///     "description": "This is a new desription.",
    ///     "id": "7250729777261217793",
    ///     "isDefault": true,
    ///     "title": "Member"
    /// }
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "member",
    ///     "description": "This is a new desription.",
    ///     "id": "7250729777261217793",
    ///     "isDefault": true,
    ///     "title": "Member"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about role.
    ///
    /// - Throws: `RoleError.incorrectRoleId` if role id is incorrect.
    /// - Throws: `EntityNotFoundError.roleNotFound` if role not exists.
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
