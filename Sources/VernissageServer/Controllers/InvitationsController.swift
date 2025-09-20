//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension InvitationsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("invitations")
    
    func boot(routes: RoutesBuilder) throws {
        let invitationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(InvitationsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        invitationsGroup
            .grouped(EventHandlerMiddleware(.invitationList))
            .grouped(CacheControlMiddleware(.noStore))
            .get(use: list)
        
        invitationsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.invitationGenerate))
            .grouped(CacheControlMiddleware(.noStore))
            .post("generate", use: generate)
        
        invitationsGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.invitationDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":id", use: delete)
    }
}

/// Controller for managing invitations.
///
/// Vernissage can have the registration of new users enabled by invitation only.
/// This controller is used to manage those invitations. It is possible to generate
/// new invitations, delete invitations not yet used, etc.
///
/// > Important: Base controller URL: `/api/v1/invitations`.
struct InvitationsController {
    
    /// List of invitations.
    ///
    /// An endpoint that returns a list of user-generated invitations.
    ///
    /// > Important: Endpoint URL: `/api/v1/invitations`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/invitations" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "code": "oZ9qXKgXVTG",
    ///     "createdAt": "2024-02-09T13:23:23.375Z",
    ///     "id": "7333587676452171777",
    ///     "updatedAt": "2024-02-09T13:23:23.375Z",
    ///     "user": { ... }
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of generated invitations.
    ///
    @Sendable
    func list(request: Request) async throws -> [InvitationDto] {
        let authorizationPayloadId = try request.requireUserId()
        let baseImagesPath = request.application.services.storageService.getBaseImagesPath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let invitationsFromDatabase = try await Invitation.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$user)
            .with(\.$invited, withDeleted: true)
            .sort(\.$invited.$id, .descending)
            .sort(\.$updatedAt)
            .all()
        
        return invitationsFromDatabase.map({ InvitationDto(from: $0, baseImagesPath: baseImagesPath, baseAddress: baseAddress) })
    }
    
    /// Generate new invitation token.
    ///
    /// An endpoint through which a user can generate a new code to invite a new user.
    ///
    /// > Important: Endpoint URL: `/api/v1/invitations/generate`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/invitations/generate" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "code": "oZ9qXKgXVTG",
    ///     "createdAt": "2024-02-09T13:23:23.375Z",
    ///     "id": "7333587676452171777",
    ///     "updatedAt": "2024-02-09T13:23:23.375Z",
    ///     "user": { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Generated invitation.
    ///
    /// - Throws: `InvitationError.maximumNumberOfInvitationsGenerated` if maximum number of invitations has been already generated.
    /// - Throws: `EntityNotFoundError.invitationNotFound` if invitation not exists.
    @Sendable
    func generate(request: Request) async throws -> InvitationDto {
        let authorizationPayloadId = try request.requireUserId()
        let generatedInvitations = try await Invitation.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .count()
        
        if !request.isAdministrator {
            let maximumNumberOfInvitations = request.application.settings.cached?.maximumNumberOfInvitations ?? 0
            guard generatedInvitations < maximumNumberOfInvitations else {
                throw InvitationError.maximumNumberOfInvitationsGenerated
            }
        }
        
        let baseImagesPath = request.application.services.storageService.getBaseImagesPath(on: request.executionContext)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let id = request.application.services.snowflakeService.generate()
        let invitation = Invitation(id: id, userId: authorizationPayloadId)
        try await invitation.save(on: request.db)
        
        guard let invitationFromDatabase = try await Invitation.query(on: request.db)
            .filter(\.$id == invitation.requireID())
            .with(\.$user)
            .with(\.$invited)
            .first() else {
            throw EntityNotFoundError.invitationNotFound
        }
        
        return InvitationDto(from: invitationFromDatabase, baseImagesPath: baseImagesPath, baseAddress: baseAddress)
    }
    
    /// Delete invitation.
    ///
    /// An endpoint through which the user can remove an invitation code that has not yet been consumed.
    ///
    /// > Important: Endpoint URL: `/api/v1/invitations/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/invitations/7333587676452171777" \
    /// -X DELETE \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    ///
    /// - Throws: `InvitationError.invalidId` if invitation id is not valid.
    /// - Throws: `InvitationError.cannotDeleteUsedInvitation` if cannot delete already used invitation.
    /// - Throws: `EntityNotFoundError.invitationNotFound` if invitation not exists.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {
        let authorizationPayloadId = try request.requireUserId()

        guard let id = request.parameters.get("id") else {
            throw InvitationError.invalidId
        }
        
        guard let invitationId = id.toId() else {
            throw InvitationError.invalidId
        }
        
        let invitation = try await Invitation.query(on: request.db)
            .filter(\.$id == invitationId)
            .filter(\.$user.$id == authorizationPayloadId)
            .first()
        
        guard let invitation else {
            throw EntityNotFoundError.invitationNotFound
        }
        
        guard invitation.$invited.id == nil else {
            throw InvitationError.cannotDeleteUsedInvitation
        }
        
        try await invitation.delete(on: request.db)
        return HTTPStatus.ok
    }
}
