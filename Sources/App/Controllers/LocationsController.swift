//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

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
    }
    
    /// Exposing NodeInfo data.
    func search(request: Request) async throws -> [LocationDto] {
        let code: String? = request.query["code"]
        let query: String? = request.query["query"]
        
        guard let query = query?.uppercased() else {
            throw Abort(.badRequest)
        }
        
        guard let code = code?.uppercased() else {
            throw Abort(.badRequest)
        }
        
        guard let countryFromDatabase = try await Country.query(on: request.db).filter(\.$code == code).first() else {
            return []
        }
        
        let locations = try await Location.query(on: request.db)
            .filter(\.$country.$id == countryFromDatabase.requireID())
            .filter(\.$namesNormalized ~~ query)
            .limit(200).all()

        return locations.map({ LocationDto(from: $0) })
    }
}
