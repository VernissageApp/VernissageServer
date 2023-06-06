//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class SearchController: RouteCollection {
    
    public static let uri: PathComponent = .constant("search")
    
    func boot(routes: RoutesBuilder) throws {
        let searchGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(SearchController.uri)
        
        searchGroup
            .grouped(EventHandlerMiddleware(.search))
            .get(use: search)
    }
    
    func search(request: Request) async throws -> UserDto {
        // Check query.
        
        // Verify blocked domain.
        
        // Search user profile by webfinger.
        
        // Download resources.
        
        // Store in our database as remote.
        
        // Return new user.
        
        throw Abort(.notFound)
    }
}
