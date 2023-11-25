//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

/// Controller for managing invitations.
final class InvitationsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("invitations")
    
    func boot(routes: RoutesBuilder) throws {
        let invitationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(InvitationsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())

        invitationsGroup
            .grouped(EventHandlerMiddleware(.invitationList))
            .get(use: list)
        
        invitationsGroup
            .grouped(EventHandlerMiddleware(.invitationGenerate))
            .post("generate", use: generate)
        
        invitationsGroup
            .grouped(EventHandlerMiddleware(.invitationDelete))
            .delete(":id", use: delete)
    }

    /// List of invitations.
    func list(request: Request) async throws -> [InvitationDto] {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let invitationsFromDatabase = try await Invitation.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$user)
            .with(\.$invited)
            .all()
        
        return invitationsFromDatabase.map({ InvitationDto(from: $0, baseStoragePath: baseStoragePath, baseAddress: baseAddress) })
    }
    
    /// Generate new invitation token.
    func generate(request: Request) async throws -> InvitationDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let generatedInvitations = try await Invitation.query(on: request.db)
            .filter(\.$user.$id == authorizationPayloadId)
            .count()
        
        let maximumNumberOfInvitations = request.application.settings.cached?.maximumNumberOfInvitations ?? 0
        guard generatedInvitations < maximumNumberOfInvitations else {
            throw InvitationError.maximumNumberOfInvitationsGenerated
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let baseAddress = request.application.settings.cached?.baseAddress ?? ""
        
        let invitation = Invitation(userId: authorizationPayloadId)
        try await invitation.save(on: request.db)
        
        guard let invitationFromDatabase = try await Invitation.query(on: request.db)
            .filter(\.$id == invitation.requireID())
            .with(\.$user)
            .with(\.$invited)
            .first() else {
            throw EntityNotFoundError.invitationNotFound
        }
        
        return InvitationDto(from: invitationFromDatabase, baseStoragePath: baseStoragePath, baseAddress: baseAddress)
    }
    
    /// Delete invitation.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        guard let id = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let invitationId = id.toId() else {
            throw Abort(.badRequest)
        }
        
        let invitation = try await Invitation.query(on: request.db)
            .filter(\.$id == invitationId)
            .filter(\.$user.$id == authorizationPayloadId)
            .first()
        
        guard invitation?.$invited.id == nil else {
            throw InvitationError.cannotDeleteUsedInvitation
        }
        
        guard let invitation else {
            throw EntityNotFoundError.invitationNotFound
        }
        
        try await invitation.delete(on: request.db)
        return HTTPStatus.ok
    }
}
