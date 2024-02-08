//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct HashtagDto {
    var url: String
    var name: String
}

extension HashtagDto: Content { }
