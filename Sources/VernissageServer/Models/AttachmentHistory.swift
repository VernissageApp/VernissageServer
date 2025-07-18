//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Photos attached to the status (history).
final class AttachmentHistory: Model, @unchecked Sendable {
    static let schema: String = "AttachmentHistories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
        
    @Field(key: "description")
    var description: String?
    
    @Field(key: "blurhash")
    var blurhash: String?
    
    @Field(key: "order")
    var order: Int
        
    @Parent(key: "originalFileId")
    var originalFile: FileInfo

    @Parent(key: "smallFileId")
    var smallFile: FileInfo

    @OptionalParent(key: "originalHdrFileId")
    var originalHdrFile: FileInfo?
    
    @OptionalParent(key: "locationId")
    var location: Location?
    
    @OptionalChild(for: \.$attachmentHistory)
    var exif: ExifHistory?
    
    @Parent(key: "statusHistoryId")
    var statusHistory: StatusHistory
    
    @Parent(key: "userId")
    var user: User
    
    @OptionalParent(key: "licenseId")
    var license: License?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusHistoryId: Int64, from attachment: Attachment) {
        self.init()

        self.id = id
        self.$statusHistory.id = statusHistoryId

        self.$user.id = attachment.$user.id
        self.$originalFile.id = attachment.$originalFile.id
        self.$smallFile.id = attachment.$smallFile.id
        self.$location.id = attachment.$location.id
        
        self.description = attachment.description
        self.blurhash = attachment.blurhash
        self.order = attachment.order
        
        if let originalHdrFileId = attachment.$originalHdrFile.id {
            self.$originalHdrFile.id = originalHdrFileId
        }
    }
}

/// Allows `AttachmentHistory` to be encoded to and decoded from HTTP messages.
extension AttachmentHistory: Content { }

extension [AttachmentHistory] {
    func sorted() -> [AttachmentHistory] {
        self.sorted { left, right in
            left.order != right.order ? left.order < right.order : (left.id ?? 0) < (right.id ?? 0)
        }
    }
}

extension MediaAttachmentDto {
    init(from attachment: AttachmentHistory, baseImagesPath: String) {
        let hdrImageUrl = MediaAttachmentDto.getOriginalHdrFileUrl(from: attachment, baseImagesPath: baseImagesPath)
        self.init(mediaType: "image/jpeg",
                  url: baseImagesPath.finished(with: "/") + attachment.originalFile.fileName,
                  name: attachment.description,
                  blurhash: attachment.blurhash,
                  width: attachment.originalFile.width,
                  height: attachment.originalFile.height,
                  hdrImageUrl: hdrImageUrl,
                  exif: MediaExifDto(from: attachment.exif),
                  location: MediaLocationDto(from: attachment.location))
    }
    
    private static func getOriginalHdrFileUrl(from attachment: AttachmentHistory, baseImagesPath: String) -> String? {
        guard let originalHdrFile = attachment.originalHdrFile else {
            return nil
        }
        
        return baseImagesPath.finished(with: "/") + originalHdrFile.fileName
    }
}
