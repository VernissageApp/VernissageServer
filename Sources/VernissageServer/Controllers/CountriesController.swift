//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension CountriesController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("countries")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(CountriesController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.countriesList))
            .get(use: list)
    }
}

/// Exposing list of countries.
///
/// When adding a new status, it is possible to assign it to a location. To narrow down the location you are
/// looking for, we first need to narrow it down to a country. This controller is used to manage the list of countries.
///
/// > Important: Base controller URL: `/api/v1/countries`.
struct CountriesController {
    
    /// Exposing list of countries.
    ///
    /// The endpoint returns a list of countries. The country code can be used to narrow down
    /// the locations in this endpoint: ``LocationsController/search(request:)``.
    ///
    /// > Important: Endpoint URL: `/api/v1/countries`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/countries" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "code": "AF",
    ///     "id": "7257110629784324097",
    ///     "name": "Afghanistan"
    /// }, {
    ///     "code": "AL",
    ///     "id": "7257110629784340481",
    ///     "name": "Albania"
    /// }, {
    ///     "code": "ZW",
    ///     "id": "7257110629788370945",
    ///     "name": "Zimbabwe"
    /// }, {
    ///     "code": "AX",
    ///     "id": "7257110629788387329",
    ///     "name": "Åland Islands"
    /// }, {
    ///     "code": "XK",
    ///     "id": "7257110629788403713",
    ///     "name": "Kosovo"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of countries.
    @Sendable
    func list(request: Request) async throws -> [CountryDto] {
        let countries = try await Country.query(on: request.db).all()
        return countries.map({ CountryDto(from: $0) })
    }
}
