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
    
    @Field(key: "originalFileName")
    var originalFileName: String

    @Field(key: "smallFileName")
    var smallFileName: String
        
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
    
    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil,
                     userId: Int64,
                     originalFileName: String,
                     smallFileName: String,
                     originalWidth: Int,
                     originalHeight: Int,
                     smallWidth: Int,
                     smallHeight: Int) {
        self.init()

        self.$user.id = userId
        self.originalFileName = originalFileName
        self.smallFileName = smallFileName
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.smallWidth = smallWidth
        self.smallHeight = smallHeight
    }
}

/// Allows `Attachment` to be encoded to and decoded from HTTP messages.
extension Attachment: Content { }
