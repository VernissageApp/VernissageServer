//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

/// Exposing list of locations.
final class LocationsController: RouteCollection {
    
    public static let uri: PathComponent = .constant("locations")
    
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
    
    /// Search by specific location.
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
