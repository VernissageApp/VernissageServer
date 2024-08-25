//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ExifDto {
    var make: String?
    var model: String?
    var lens: String?
    var createDate: String?
    var focalLenIn35mmFilm: String?
    var fNumber: String?
    var exposureTime: String?
    var photographicSensitivity: String?
    var film: String?
}

extension ExifDto {
    init?(from exif: Exif?) {
        guard let exif else {
            return nil
        }
        
        self.init(make: exif.make,
                  model: exif.model,
                  lens: exif.lens,
                  createDate: exif.createDate,
                  focalLenIn35mmFilm: exif.focalLenIn35mmFilm,
                  fNumber: exif.fNumber,
                  exposureTime: exif.exposureTime,
                  photographicSensitivity: exif.photographicSensitivity,
                  film: exif.film)
    }
}

extension ExifDto: Content { }

extension ExifDto {
    public func hasAnyMetadata() -> Bool {
        make != nil ||
        model != nil ||
        lens != nil ||
        createDate != nil ||
        focalLenIn35mmFilm != nil ||
        fNumber != nil ||
        exposureTime != nil ||
        photographicSensitivity != nil ||
        film != nil
    }
}
