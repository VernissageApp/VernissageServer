//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// City location.
final class Location: Model, @unchecked Sendable {
    static let schema: String = "Locations"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "geonameId")
    var geonameId: String
    
    @Field(key: "name")
    var name: String

    @Field(key: "namesNormalized")
    var namesNormalized: String
        
    @Field(key: "longitude")
    var longitude: String

    @Field(key: "latitude")
    var latitude: String
        
    @Parent(key: "countryId")
    var country: Country
    
    @Children(for: \.$location)
    var attachment: [Attachment]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = Snowflake.identifier()
    }

    convenience init(id: Int64? = nil,
                     countryId: Int64,
                     geonameId: String,
                     name: String,
                     namesNormalized: String,
                     longitude: String,
                     latitude: String) {
        self.init()

        self.$country.id = countryId
        self.geonameId = geonameId
        self.name = name
        self.namesNormalized = namesNormalized
        self.longitude = longitude
        self.latitude = latitude
    }
}

/// Allows `Location` to be encoded to and decoded from HTTP messages.
extension Location: Content { }

extension MediaLocationDto {
    init?(from location: Location?) {
        guard let location else {
            return nil
        }
        
        self.init(
            geonameId: location.geonameId,
            name: location.name,
            longitude: location.longitude,
            latitude: location.latitude,
            countryCode: location.country.code,
            countryName: location.country.name
        )
    }
}
