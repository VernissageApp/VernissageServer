//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
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

    @Field(key: "film")
    var film: String?
    
    @Parent(key: "attachmentId")
    var attachment: Attachment
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init?(id: Int64? = nil,
                      make: String? = nil,
                      model: String? = nil,
                      lens: String? = nil,
                      createDate: String? = nil,
                      focalLenIn35mmFilm: String? = nil,
                      fNumber: String? = nil,
                      exposureTime: String? = nil,
                      photographicSensitivity: String? = nil,
                      film: String? = nil) {
        if make == nil && model == nil && lens == nil && createDate == nil
            && focalLenIn35mmFilm == nil && fNumber == nil && exposureTime == nil && photographicSensitivity == nil && film == nil {
            return nil
        }
        
        self.init()

        self.make = make
        self.model = model
        self.lens = lens
        self.createDate = createDate
        self.focalLenIn35mmFilm = focalLenIn35mmFilm
        self.fNumber = fNumber
        self.exposureTime = exposureTime
        self.photographicSensitivity = photographicSensitivity
        self.film = film
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
            film: exif.film
        )
    }
}
