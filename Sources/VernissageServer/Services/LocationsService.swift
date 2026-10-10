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
    /// Fills the database with location data from external resource files if not already populated.
    ///
    /// - Parameter context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if the operation fails, for example due to a file read or database issue.
    func fill(on context: ExecutionContext) async throws
}

/// A service for managing locations.
final class LocationsService: LocationsServiceType {

    public func fill(on context: ExecutionContext) async throws {
        if context.application.environment == .testing {
            context.logger.notice("Locations are not initialized during testing (testing environment is set).")
            return
        }
        
        try await self.fill(from: "geonames.json", expectedLocationsCount: 140_992, on: context)
        try await self.fill(from: "geonames-20261005.json", expectedLocationsCount: 171_209, on: context)
    }

    private func fill(from fileName: String, expectedLocationsCount: Int, on context: ExecutionContext) async throws {
        // The expected count includes locations imported from earlier files.
        if try await Location.query(on: context.db).count() >= expectedLocationsCount {
            context.logger.info("Locations from '\(fileName)' already added to database.")
            return
        }
        
        context.logger.info("Locations from '\(fileName)' have to be added to the database, this may take a while.")
        let geonamesPath = context.application.directory.resourcesDirectory.finished(with: "/") + fileName
        
        guard let fileHandle = FileHandle(forReadingAtPath: geonamesPath) else {
            context.logger.notice("File with locations cannot be opened ('\(geonamesPath)').")
            return
        }

        defer { try? fileHandle.close() }
        
        guard let fileData = try fileHandle.readToEnd() else {
            context.logger.notice("Cannot read file with locations ('\(geonamesPath)').")
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
        
        context.logger.info("All locations from '\(fileName)' added.")
    }
    
}
