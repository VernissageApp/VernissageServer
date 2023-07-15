//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct MetadataDto {
    var original: SizeDto
    var small: SizeDto
    var exif: ExifDto?
}

extension MetadataDto {
    init(originalWidth: Int, originalHeight: Int, smallWidth: Int, smallHeight: Int, exif: Exif?) {
        self.original = SizeDto(width: originalWidth, height: originalHeight)
        self.small = SizeDto(width: smallWidth, height: smallHeight)
        self.exif = ExifDto(from: exif)
    }
}

extension MetadataDto: Content { }
