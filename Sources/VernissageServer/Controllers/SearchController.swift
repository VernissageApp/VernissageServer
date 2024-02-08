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
final class SearchController {
    
    /// Searching.
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
