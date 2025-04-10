//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ConfigurationStatusesDto {
    var maxCharacters: Int
    var maxMediaAttachments: Int
    var charactersReservedPerUrl: Int
}

extension ConfigurationStatusesDto: Content { }
