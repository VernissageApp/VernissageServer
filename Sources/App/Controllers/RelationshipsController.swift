//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class RelationshipsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("relationships")
    
    func boot(routes: RoutesBuilder) throws {
        let relationshipsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(RelationshipsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        relationshipsGroup
            .grouped(EventHandlerMiddleware(.relationships))
            .get(use: relationships)
    }
    
    /// Exposing list of relationships.
    func relationships(request: Request) async throws -> [RelationshipDto] {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }

        // Get ids from query string.
        let stringIds = try request.query.get([String].self, at: "id")

        // Translate strings into Int64 array.
        var ids: [Int64] = []
        try stringIds.forEach({
            guard let id = $0.toId() else {
                throw Abort(.badRequest)
            }
            
            ids.append(id)
        })
        
        let followsService = request.application.services.followsService
        return try await followsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: ids)
    }
}