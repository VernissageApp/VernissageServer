//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct AttachmentDto {
    var id: String?
    var originalFile: FileInfoDto
    var smallFile: FileInfoDto
    var description: String?
    var blurhash: String?
    var metadata: MetadataDto?
    var location: LocationDto?
}

extension AttachmentDto {
    init(from attachment: Attachment, baseStoragePath: String) {
        let url = AttachmentDto.getUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        
        self.init(id: attachment.stringId(),
                  originalFile: FileInfoDto(url: url, width: attachment.originalFile.width, height: attachment.originalFile.height),
                  smallFile: FileInfoDto(url: previewUrl, width: attachment.smallFile.width, height: attachment.smallFile.height),
                  description: attachment.description,
                  blurhash: attachment.blurhash,
                  metadata: MetadataDto(exif: attachment.exif),
                  location: AttachmentDto.getLocation(location: attachment.location))
    }
    
    private static func getLocation(location: Location?) -> LocationDto? {
        guard let location else {
            return nil
        }
        
        return LocationDto(from: location)
    }
    
    private static func getUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.originalFile.fileName
    }
    
    private static func getPreviewUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.smallFile.fileName
    }
}

extension AttachmentDto: Content { }
