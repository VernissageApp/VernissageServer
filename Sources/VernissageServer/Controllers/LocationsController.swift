//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension LocationsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("locations")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(LocationsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.locationsList))
            .get(use: search)
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.locationsRead))
            .get(":id", use: read)
    }
}

/// Exposing list of locations.
///
/// Each mage can be linked to a location, so you know where the photo was taken.
/// The location is limited only to the city where the photo was taken, so there are no
/// worries about compromising privacy.
///
/// > Important: Base controller URL: `/api/v1/locations`.
final class LocationsController {
        
    /// Search by specific location.
    ///
    /// An endpoint that returns a list of locations added to the system.
    /// The location `id` is used when adding a new attachment to the system.
    ///
    /// Query params:
    /// - `code` - country code
    /// - `query` - part of the city name
    ///
    /// > Important: Endpoint URL: `/api/v1/locations`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/locations?code=PL&query=wro" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// [{
    ///     "country": {
    ///         "code": "PL",
    ///         "id": "7257110629787191297",
    ///         "name": "Poland"
    ///     },
    ///     "id": "7257110681330513921",
    ///     "latitude": "51,61215",
    ///     "longitude": "18,61487",
    ///     "name": "Wróblew"
    /// }, {
    ///     "country": {
    ///         "code": "PL",
    ///         "id": "7257110629787191297",
    ///         "name": "Poland"
    ///     },
    ///     "id": "7257111054999695361",
    ///     "latitude": "51,0361",
    ///     "longitude": "16,9677",
    ///     "name": "Bielany Wrocławskie"
    /// }]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: List of locations.
    func search(request: Request) async throws -> [LocationDto] {
        let code: String? = request.query["code"]
        let query: String? = request.query["query"]
        
        guard let query = query?.uppercased() else {
            throw Abort(.badRequest)
        }
                
        if let code = code?.uppercased() {
            let locations = try await Location.query(on: request.db)
                .join(Country.self, on: \Location.$country.$id == \Country.$id)
                .filter(Country.self, \.$code == code)
                .filter(\.$namesNormalized ~~ query)
                .with(\.$country)
                .limit(200).all()
            
            return locations.map({ LocationDto(from: $0) })
        } else {
            let locations = try await Location.query(on: request.db)
                .filter(\.$namesNormalized ~~ query)
                .with(\.$country)
                .limit(200).all()
            
            return locations.map({ LocationDto(from: $0) })
        }
    }
    
    /// Get specific location.
    ///
    /// An endpoint that returns a list of locations added to the system.
    /// The location `id` is used when adding a new attachment to the system.
    ///
    /// > Important: Endpoint URL: `/api/v1/locations/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/locations/7257110681330513921" \
    /// -X GET \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "country": {
    ///         "code": "PL",
    ///         "id": "7257110629787191297",
    ///         "name": "Poland"
    ///     },
    ///     "id": "7257110681330513921",
    ///     "latitude": "51,61215",
    ///     "longitude": "18,61487",
    ///     "name": "Wróblew"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about location.
    ///
    /// - Throws: `LocationError.incorrectLocationId` if location id is incorrect.
    /// - Throws: `EntityNotFoundError.locationNotFound` if location not exists.
    func read(request: Request) async throws -> LocationDto {
        guard let locationIdString = request.parameters.get("id", as: String.self) else {
            throw LocationError.incorrectLocationId
        }
        
        guard let locationId = locationIdString.toId() else {
            throw LocationError.incorrectLocationId
        }

        let location = try await Location.query(on: request.db)
            .filter(\.$id == locationId)
            .with(\.$country)
            .first()

        guard let location else {
            throw EntityNotFoundError.locationNotFound
        }
        
        return LocationDto(from: location)
    }
}
