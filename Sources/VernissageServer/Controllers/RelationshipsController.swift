//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension RelationshipsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("relationships")
    
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
}

/// Exposing information about user's relatioinships.
///
/// Controller, through which it is possible to retrieve information about
/// the relationship between two users.
///
/// > Important: Base controller URL: `/api/v1/relationships`.
final class RelationshipsController {
    
    /// Exposing list of relationships.
    ///
    /// An endpoint that returns information about the association between a logged-in
    /// user and one or more users whose id numbers are sent in the query parameters.
    ///
    /// > Important: Endpoint URL: `/api/v1/relationships`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/relationships?id[]=7260098629943709697&id[]=7265253398152519681" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "followedBy": true,
    ///     "following": true,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7260098629943709697"
    /// }, {
    ///     "followedBy": true,
    ///     "following": true,
    ///     "mutedNotifications": false,
    ///     "mutedReblogs": false,
    ///     "mutedStatuses": false,
    ///     "requested": false,
    ///     "requestedBy": false,
    ///     "userId": "7265253398152519681"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of relationships information.
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
        
        let relationshipsService = request.application.services.relationshipsService
        return try await relationshipsService.relationships(on: request.db, userId: authorizationPayloadId, relatedUserIds: ids)
    }
}
