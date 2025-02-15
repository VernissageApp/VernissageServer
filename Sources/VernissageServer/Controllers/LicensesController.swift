//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension LicensesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("licenses")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(LicensesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.licensesList))
            .grouped(CacheControlMiddleware(.public()))
            .get(use: list)
    }
}

/// Exposing list of supported licenses.
///
/// Each status can have a license assigned to it, so you know whether you
/// can further distribute the work and under what conditions.
///
/// > Important: Base controller URL: `/api/v1/licenses`.
struct LicensesController {
    
    /// Exposing list of licenses.
    ///
    /// An endpoint that returns a list of licenses added to the system.
    /// The license `id` is used when adding a new status to the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/licenses`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/licenses" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "code": "",
    ///     "description": "You, the copyright holder, ... waived under this license.",
    ///     "id": "7310961711425626113",
    ///     "name": "All Rights Reserved"
    /// }, {
    ///     "code": "CC BY-NC-ND",
    ///     "description": "This license allows reusers ... is given to the creator.",
    ///     "id": "7310961711425757185",
    ///     "name": "Attribution-NonCommercial-NoDerivs",
    ///     "url": "https:\/\/creativecommons.org\/licenses\/by-nc-nd\/4.0\/"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of countries.
    @Sendable
    func list(request: Request) async throws -> [LicenseDto] {
        let licenses = try await License.query(on: request.db)
            .sort(\.$id)
            .all()

        return licenses.map({ LicenseDto(from: $0) })
    }
}
