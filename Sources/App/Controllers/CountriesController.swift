//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

final class CountriesController: RouteCollection {
    
    public static let uri: PathComponent = .constant("countries")
    
    func boot(routes: RoutesBuilder) throws {
        let locationsGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        locationsGroup
            .grouped(EventHandlerMiddleware(.webfinger))
            .get(CountriesController.uri, use: list)
    }
    
    /// Exposing list of countries.
    func list(request: Request) async throws -> [CountryDto] {
        let countries = try await Country.query(on: request.db).all()
        return countries.map({ CountryDto(from: $0) })
    }
}
