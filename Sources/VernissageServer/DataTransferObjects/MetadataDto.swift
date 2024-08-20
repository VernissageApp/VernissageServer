//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct MetadataDto {
    var exif: ExifDto?
}

extension MetadataDto {
    init(exif: Exif?) {
        self.exif = ExifDto(from: exif)
    }
}

extension MetadataDto: Content { }
