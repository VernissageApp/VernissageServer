//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Exif information from image (history).
final class ExifHistory: Model, @unchecked Sendable {
    static let schema: String = "ExifHistories"

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
    
    @Parent(key: "attachmentHistoryId")
    var attachmentHistory: AttachmentHistory
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, attachmentHistoryId: Int64, from exif: Exif) {
        self.init()

        self.id = id
        self.$attachmentHistory.id = attachmentHistoryId

        self.make = exif.make
        self.model = exif.model
        self.lens = exif.lens
        self.createDate = exif.createDate
        self.focalLenIn35mmFilm = exif.focalLenIn35mmFilm
        self.fNumber = exif.fNumber
        self.exposureTime = exif.exposureTime
        self.photographicSensitivity = exif.photographicSensitivity
        self.film = exif.film
        self.latitude = exif.latitude
        self.longitude = exif.longitude
        self.flash = exif.flash
        self.focalLength = exif.focalLength
    }
}

/// Allows `ExifHistory` to be encoded to and decoded from HTTP messages.
extension ExifHistory: Content { }

extension MediaExifDto {
    init?(from exif: ExifHistory?) {
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
