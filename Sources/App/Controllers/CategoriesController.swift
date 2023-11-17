//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class CategoriesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("categories")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(CategoriesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.categoriesList))
            .get(use: list)
    }
    
    /// Exposing list of countries.
    func list(request: Request) async throws -> [CategoryDto] {
        let categories = try await Category.query(on: request.db)
            .sort(\.$name, .ascending)
            .all()
        return categories.map({ CategoryDto(from: $0) })
    }
}
