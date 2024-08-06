//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension CategoriesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("categories")
    
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
}

/// Exposing list of categories.
///
/// Each status can be assigned to at most one category. This controller is used to manage categories in the system.
/// Also, statuses downloaded through ActivityPub are automatically assigned to categories by mapping hashtags to categories.
///
/// > Important: Base controller URL: `/api/v1/categories`.
final class CategoriesController {
    
    /// Exposing list of categories.
    ///
    /// The endpoint returns a list of all categories that are added to the system.
    ///
    /// Optional query params:
    /// - `onlyUsed` - `true` if list should contain only categories which has been used
    ///
    /// > Important: Endpoint URL: `/api/v1/categories`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/categories" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "id": "7302167186067544065",
    ///     "name": "Abstract"
    /// }, {
    ///     "id": "7302167186067558401",
    ///     "name": "Aerial"
    /// }, {
    ///     "id": "7302167186067845121",
    ///     "name": "Transportation"
    /// }, {
    ///     "id": "7302167186067859457",
    ///     "name": "Travel"
    /// }, {
    ///     "id": "7302167186067873793",
    ///     "name": "Wedding"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of categories.
    func list(request: Request) async throws -> [CategoryDto] {
        let onlyUsed: Bool = request.query["onlyUsed"] ?? false
        
        let categories = try await Category.query(on: request.db)
            .sort(\.$name, .ascending)
            .all()
        
        if onlyUsed {
            var usedCategories: [Category] = []

            try await categories.asyncForEach { category in
                if let _ = try await Status.query(on: request.db)
                    .filter(\.$category.$id == category.requireID())
                    .first() {
                    usedCategories.append(category)
                }
            }
            
            return usedCategories.map({ CategoryDto(from: $0) })
        }
        
        return categories.map({ CategoryDto(from: $0) })
    }
}
