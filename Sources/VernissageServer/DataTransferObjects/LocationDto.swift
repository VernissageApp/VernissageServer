//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LocationDto {
    var id: String?
    var name: String
    var longitude: String
    var latitude: String
    var country: CountryDto
}

extension LocationDto {
    init(from location: Location) {
        self.init(id: location.stringId(),
                  name: location.name,
                  longitude: location.longitude,
                  latitude: location.latitude,
                  country: CountryDto(from: location.country))
    }
}

extension LocationDto: Content { }
