//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct EmailAddressDto {
    var address: String
    var name: String?
}

extension EmailAddressDto: Content { }
