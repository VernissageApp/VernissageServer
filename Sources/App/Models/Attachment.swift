//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

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
    
    @OptionalParent(key: "statusId")
    var status: Status?
    
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
                     smallFileId: Int64,
                     description: String? = nil,
                     blurhash: String? = nil,
                     locationId: Int64? = nil) {
        self.init()

        self.$user.id = userId
        self.$originalFile.id = originalFileId
        self.$smallFile.id = smallFileId
        self.description = description
        self.blurhash = blurhash
        self.$location.id = locationId
    }
}

/// Allows `Attachment` to be encoded to and decoded from HTTP messages.
extension Attachment: Content { }

extension MediaAttachmentDto {
    init(from attachment: Attachment, baseStoragePath: String) {
        self.init(mediaType: "image/jpeg",
                  url: baseStoragePath.finished(with: "/") + attachment.originalFile.fileName,
                  name: attachment.description,
                  blurhash: attachment.blurhash,
                  width: attachment.originalFile.width,
                  height: attachment.originalFile.height,
                  exif: MediaExifDto(from: attachment.exif),
                  location: MediaLocationDto(from: attachment.location))
    }
}
