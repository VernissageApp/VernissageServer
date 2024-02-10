//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct CountryDto {
    var id: String?
    var name: String
    var code: String
}

extension CountryDto {
    init(from country: Country) {
        self.init(id: country.stringId(),
                  name: country.name,
                  code: country.code)
    }
}

extension CountryDto: Content { }
