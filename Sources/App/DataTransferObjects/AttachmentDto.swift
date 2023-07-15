//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct AttachmentDto {
    var id: String?
    var url: String
    var previewUrl: String
    var description: String?
    var blurhash: String?
    var metadata: MetadataDto?
}

extension AttachmentDto {
    init(from attachment: Attachment, exif: Exif?, baseStoragePath: String) {
        let url = AttachmentDto.getUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        
        self.init(id: attachment.stringId(),
                  url: url,
                  previewUrl: previewUrl,
                  description: attachment.description,
                  blurhash: attachment.blurhash,
                  metadata: MetadataDto(originalWidth: attachment.originalWidth,
                                        originalHeight: attachment.originalHeight,
                                        smallWidth: attachment.smallWidth,
                                        smallHeight: attachment.smallHeight,
                                        exif: exif))
    }
    
    private static func getUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.originalFileName
    }
    
    private static func getPreviewUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.smallFileName
    }
}

extension AttachmentDto: Content { }
