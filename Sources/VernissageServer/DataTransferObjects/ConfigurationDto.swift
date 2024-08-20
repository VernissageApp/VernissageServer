//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ConfigurationDto {
    var statuses: ConfigurationStatusesDto
    var attachments: ConfigurationAttachmentsDto
}

extension ConfigurationDto: Content { }
