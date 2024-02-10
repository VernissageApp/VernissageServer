//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension SearchController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("search")
    
    func boot(routes: RoutesBuilder) throws {
        let searchGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SearchController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        searchGroup
            .grouped(EventHandlerMiddleware(.search))
            .get(use: search)
    }
}

/// Controller for search feature.
///
/// Controller used to search for users on the local server and on remote servers.
/// The search on the remote server is performed using the Webfinger protocol.
///
/// > Important: Base controller URL: `/api/v1/search`.
final class SearchController {
    
    /// Searching.
    ///
    /// An endpoint used to search for objects of various types on the local server
    /// and in other fediverse instances.
    ///
    /// Query params:
    /// - `query` - query/user name to search
    /// - `type` - type of the object: `users`, `statuses`, `hashtags`.
    ///
    /// > Important: Endpoint URL: `/api/v1/search`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/search?query=johndoe@example.com&type=users" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "users": [
    ///         {
    ///             "account": "johndoe@example.com",
    ///             "activityPubProfile": "https://example.com/actors/johndoe",
    ///             "avatarUrl": "https://example.com/09e90695cfc54d7795e14f8a57852334.jpg",
    ///             "bio": "#iOS/#dotNET developer",
    ///             "bioHtml": "#iOS/#dotNET developer",
    ///             "createdAt": "2024-02-09T16:12:52.136Z",
    ///             "fields": [],
    ///             "followersCount": 0,
    ///             "followingCount": 0,
    ///             "headerUrl": "https://example.com/d40bac5bc2f3407bbadb967a0d4346df.jpg",
    ///             "id": "7333632348405161985",
    ///             "isLocal": false,
    ///             "name": "John Doe",
    ///             "statusesCount": 0,
    ///             "updatedAt": "2024-02-09T16:12:52.136Z",
    ///             "userName": "johndoe@example.com"
    ///         }
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of found entities.
    func search(request: Request) async throws -> SearchResultDto {
        let query: String? = request.query["query"]
        let typeString: String? = request.query["type"]
        
        // Query have to be specified.
        guard let query else {
            throw Abort(.badRequest)
        }
        
        // Get type of search.
        let searchType = self.getSearchType(from: typeString)
        
        // Execute proper search.
        let searchService = request.application.services.searchService
        return try await searchService.search(query: query, searchType: searchType, request: request)
    }
    
    private func getSearchType(from typeString: String?) -> SearchTypeDto {
        guard let typeString else {
            return .users
        }
        
        return SearchTypeDto(rawValue: typeString) ?? .users
    }
}
