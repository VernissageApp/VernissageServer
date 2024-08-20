//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Location {
    static func create(name: String) async throws -> Location {
        guard let country = try await Country.query(on: SharedApplication.application().db).filter(\.$code == "PL").first() else {
            throw SharedApplicationError.unwrap
        }

        let location = try Location(countryId: country.requireID(),
                                    geonameId: name,
                                    name: name,
                                    namesNormalized: name.uppercased(),
                                    longitude: "17,03333",
                                    latitude: "51,1")
        
        _ = try await location.save(on: SharedApplication.application().db)
        return location
    }
}
