//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createLocation(name: String) async throws -> Location {
        guard let country = try await Country.query(on: self.db).filter(\.$code == "PL").first() else {
            throw SharedApplicationError.unwrap
        }

        let id = await ApplicationManager.shared.generateId()
        let location = try Location(id: id,
                                    countryId: country.requireID(),
                                    geonameId: name,
                                    name: name,
                                    namesNormalized: name.uppercased(),
                                    longitude: "17,03333",
                                    latitude: "51,1")
        
        _ = try await location.save(on: self.db)
        return location
    }
}
