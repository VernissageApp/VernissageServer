//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct BusinessCardAvatarDto {
    var file: String
    var type: String
}

extension BusinessCardAvatarDto: Content { }
