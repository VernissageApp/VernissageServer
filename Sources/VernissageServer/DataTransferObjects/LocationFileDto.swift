//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LocationFileDto {
    var geonameId: String
    var name: String
    var namesNormalized: String
    var countryCode: String
    var longitude: String
    var latitude: String
}

extension LocationFileDto: Content { }
