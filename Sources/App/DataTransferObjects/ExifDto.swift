//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
                  photographicSensitivity: exif.photographicSensitivity)
    }
}

extension ExifDto: Content { }
