//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct LocationsServiceKey: StorageKey {
        typealias Value = LocationsServiceType
    }

    var locationsService: LocationsServiceType {
        get {
            self.application.storage[LocationsServiceKey.self] ?? LocationsService()
        }
        nonmutating set {
            self.application.storage[LocationsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol LocationsServiceType: Sendable {
    func fill(on context: ExecutionContext) async throws
}

/// A service for managing locatiions.
final class LocationsService: LocationsServiceType {

    public func fill(on context: ExecutionContext) async throws {
        if context.application.environment == .testing {
            context.logger.notice("Locations are not initialized during testing (testing environment is set).")
            return
        }
        
        // Current number of locations in geonames.json file.
        if try await Location.query(on: context.db).count() == 140_992 {
            context.logger.info("All locations already added to database.")
            return
        }
        
        context.logger.info("Locations have to be added to the database, this may take a while.")
        let geonamesPath = context.application.directory.resourcesDirectory.finished(with: "/") + "geonames.json"
        
        guard let fileHandle = FileHandle(forReadingAtPath: geonamesPath) else {
            context.logger.notice("File with locations cannot be opened ('\(geonamesPath)').")
            return
        }
        
        guard let fileData = try fileHandle.readToEnd() else {
            context.logger.notice("Cannot read file with locataions ('\(geonamesPath)').")
            return
        }
        
        let countries = try await Country.query(on: context.db).all()
        let locations = try JSONDecoder().decode([LocationFileDto].self, from: fileData)
        
        for (index, location) in locations.enumerated() {
            if index % 1000 == 0 {
                context.logger.info("Added locations: \(index).")
            }

            guard let countryId = countries.first(where: { $0.code == location.countryCode.uppercased() })?.id else {
                context.logger.notice("Country code not found: '\(location.countryCode)'. Operation interrupted.")
                break
            }
            
            let locationFromDatabase = try await Location.query(on: context.db).filter(\.$geonameId == location.geonameId).first()
            guard locationFromDatabase == nil else {
                continue
            }
            
            let id = context.services.snowflakeService.generate()
            let locationDb = Location(id: id,
                                      countryId: countryId,
                                      geonameId: location.geonameId,
                                      name: location.name,
                                      namesNormalized: location.namesNormalized,
                                      longitude: location.longitude,
                                      latitude: location.latitude)
            
            try await locationDb.create(on: context.db)
        }
        
        context.logger.info("All locations added.")
    }
    
}
