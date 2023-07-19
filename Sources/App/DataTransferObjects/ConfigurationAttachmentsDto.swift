//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ConfigurationAttachmentsDto {
    var supportedMimeTypes: [String]
    var imageSizeLimit: Int
}

extension ConfigurationAttachmentsDto: Content { }
