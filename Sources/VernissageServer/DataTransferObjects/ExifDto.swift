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
    var software: String?
    var film: String?
    var chemistry: String?
    var scanner: String?
    var latitude: String?
    var longitude: String?
    var flash: String?
    var focalLength: String?
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
                  software: exif.software,
                  film: exif.film,
                  chemistry: exif.chemistry,
                  scanner: exif.scanner,
                  latitude: exif.latitude,
                  longitude: exif.longitude,
                  flash: exif.flash,
                  focalLength: exif.focalLength)
    }
    
    init?(from exif: ExifHistory?) {
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
                  software: exif.software,
                  film: exif.film,
                  chemistry: exif.chemistry,
                  scanner: exif.scanner,
                  latitude: exif.latitude,
                  longitude: exif.longitude,
                  flash: exif.flash,
                  focalLength: exif.focalLength)
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
        software != nil ||
        film != nil ||
        chemistry != nil ||
        scanner != nil ||
        latitude != nil ||
        longitude != nil ||
        flash != nil ||
        focalLength != nil
    }
}
