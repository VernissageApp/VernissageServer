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
        
    @Field(key: "description")
    var description: String?
    
    @Field(key: "blurhash")
    var blurhash: String?
        
    @Parent(key: "originalFileId")
    var originalFile: FileInfo

    @Parent(key: "smallFileId")
    var smallFile: FileInfo

    @OptionalParent(key: "locationId")
    var location: Location?
    
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
                     originalFileId: Int64,
                     smallFileId: Int64) {
        self.init()

        self.$user.id = userId
        self.$originalFile.id = originalFileId
        self.$smallFile.id = smallFileId
    }
}

/// Allows `Attachment` to be encoded to and decoded from HTTP messages.
extension Attachment: Content { }
