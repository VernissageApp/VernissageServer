//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Attachment: Model {
    static let schema: String = "Attachments"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "fileName")
    var fileName: String

    @Field(key: "fileSize")
    var fileSize: Int
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "blurhash")
    var blurhash: String?
    
    @Field(key: "originalWidth")
    var originalWidth: Int
    
    @Field(key: "originalHeight")
    var originalHeight: Int
    
    @Field(key: "smallWidth")
    var smallWidth: Int
    
    @Field(key: "smallHeight")
    var smallHeight: Int
    
    @OptionalChild(for: \.$attachment)
    var exif: Exif?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil,
                     fileName: String,
                     fileSize: Int,
                     description: String?,
                     blurhash: String?,
                     originalWidth: Int,
                     originalHeight: Int,
                     smallWidth: Int,
                     smallHeight: Int) {
        self.init()

        self.fileName = fileName
        self.fileSize = fileSize
        self.description = description
        self.blurhash = blurhash
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.smallWidth = smallWidth
        self.smallHeight = smallHeight
    }
}

/// Allows `Attachment` to be encoded to and decoded from HTTP messages.
extension Attachment: Content { }
