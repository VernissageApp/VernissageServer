//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Exif information from image.
final class Exif: Model, @unchecked Sendable {
    static let schema: String = "Exif"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "make")
    var make: String?
    
    @Field(key: "model")
    var model: String?
    
    @Field(key: "lens")
    var lens: String?
    
    @Field(key: "createDate")
    var createDate: String?
    
    @Field(key: "focalLenIn35mmFilm")
    var focalLenIn35mmFilm: String?
    
    @Field(key: "fNumber")
    var fNumber: String?
    
    @Field(key: "exposureTime")
    var exposureTime: String?
    
    @Field(key: "photographicSensitivity")
    var photographicSensitivity: String?

    @Field(key: "software")
    var software: String?
    
    @Field(key: "film")
    var film: String?
    
    @Field(key: "chemistry")
    var chemistry: String?

    @Field(key: "scanner")
    var scanner: String?
    
    @Field(key: "latitude")
    var latitude: String?
    
    @Field(key: "longitude")
    var longitude: String?

    @Field(key: "flash")
    var flash: String?
    
    @Field(key: "focalLength")
    var focalLength: String?
    
    @Parent(key: "attachmentId")
    var attachment: Attachment
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init?(id: Int64,
                      make: String? = nil,
                      model: String? = nil,
                      lens: String? = nil,
                      createDate: String? = nil,
                      focalLenIn35mmFilm: String? = nil,
                      fNumber: String? = nil,
                      exposureTime: String? = nil,
                      photographicSensitivity: String? = nil,
                      software: String? = nil,
                      film: String? = nil,
                      scanner: String? = nil,
                      chemistry: String? = nil,
                      latitude: String? = nil,
                      longitude: String? = nil,
                      flash: String? = nil,
                      focalLength: String? = nil) {
        if make == nil && model == nil && lens == nil && createDate == nil
            && focalLenIn35mmFilm == nil && fNumber == nil && exposureTime == nil
            && photographicSensitivity == nil && software == nil && film == nil && scanner == nil
            && latitude == nil && longitude == nil && flash == nil && focalLength == nil && chemistry == nil {
            return nil
        }
        
        self.init()

        self.id = id
        self.make = make
        self.model = model
        self.lens = lens
        self.createDate = createDate
        self.focalLenIn35mmFilm = focalLenIn35mmFilm
        self.fNumber = fNumber
        self.exposureTime = exposureTime
        self.photographicSensitivity = photographicSensitivity
        self.software = software
        self.film = film
        self.chemistry = chemistry
        self.scanner = scanner
        self.latitude = latitude
        self.longitude = longitude
        self.flash = flash
        self.focalLength = focalLength
    }
    
    convenience init?(id: Int64, exifData: [MediaExifDataDto]?) {
        guard let exifData else {
            return nil
        }
        
        guard exifData.count > 0 else {
            return nil
        }
        
        if exifData.make == nil && exifData.model == nil && exifData.lensModel == nil && exifData.createDateParsed == nil
            && exifData.focalLenIn35mmFilm == nil && exifData.fNumber == nil && exifData.exposureTime == nil
            && exifData.photographicSensitivity == nil && exifData.software == nil && exifData.film == nil
            && exifData.latitude == nil && exifData.longitude == nil && exifData.flash == nil
            && exifData.focalLength == nil && exifData.scanner == nil && exifData.chemistry == nil {
            return nil
        }
        
        self.init()

        self.id = id
        self.make = exifData.make
        self.model = exifData.model
        self.lens = exifData.lensModel
        self.createDate = exifData.createDateParsed
        self.focalLenIn35mmFilm = exifData.focalLenIn35mmFilm
        self.fNumber = exifData.fNumber
        self.exposureTime = exifData.exposureTime
        self.photographicSensitivity = exifData.photographicSensitivity
        self.software = exifData.software
        self.chemistry = nil
        self.latitude = exifData.latitude
        self.longitude = exifData.longitude
        self.flash = exifData.flash
        self.focalLength = exifData.focalLength
        
        self.film = exifData.film
        self.scanner = exifData.scanner
        self.chemistry = exifData.chemistry
    }
}

/// Allows `Metadata` to be encoded to and decoded from HTTP messages.
extension Exif: Content { }

extension MediaExifDto {
    init?(from exif: Exif?) {
        guard let exif else {
            return nil
        }
        
        self.init(
            make: exif.make,
            model: exif.model,
            lens: exif.lens,
            createDate: exif.createDate,
            focalLenIn35mmFilm: exif.focalLenIn35mmFilm,
            fNumber: exif.fNumber,
            exposureTime: exif.exposureTime,
            photographicSensitivity: exif.photographicSensitivity,
            film: exif.film,
            latitude: exif.latitude,
            longitude: exif.longitude,
            flash: exif.flash,
            focalLength: exif.focalLength
        )
    }
}

extension Exif {
    func toExifData() -> [MediaExifDataDto] {
        var exifData: [MediaExifDataDto] = []
        exifData.make = self.make
        exifData.model = self.model
        exifData.lensModel = self.lens
        exifData.createDateParsed = self.createDate
        exifData.focalLenIn35mmFilm = self.focalLenIn35mmFilm
        exifData.fNumber = self.fNumber
        exifData.exposureTime = self.exposureTime
        exifData.photographicSensitivity = self.photographicSensitivity
        exifData.software = self.software
        exifData.latitude = self.latitude
        exifData.longitude = self.longitude
        exifData.flash = self.flash
        exifData.focalLength = self.focalLength
        
        exifData.film = self.film
        exifData.scanner = self.scanner
        exifData.chemistry = self.chemistry
     
        return exifData
    }
}
