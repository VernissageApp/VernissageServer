//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusContextDto {
    var ancestors: [StatusDto]
    var descendants: [StatusDto]
}

extension StatusContextDto: Content { }

