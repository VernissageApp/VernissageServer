//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct AttachmentDto {
    var id: String?
    var originalFile: FileInfoDto
    var smallFile: FileInfoDto
    var originalHdrFile: FileInfoDto?
    var description: String?
    var blurhash: String?
    var metadata: MetadataDto?
    var location: LocationDto?
    var license: LicenseDto?
}

extension AttachmentDto {
    init(from attachment: Attachment, baseStoragePath: String) {
        let url = AttachmentDto.getUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        let originalHdrFile = AttachmentDto.getOrginalHdrFile(attachment: attachment, baseStoragePath: baseStoragePath)
        
        self.init(id: attachment.stringId(),
                  originalFile: FileInfoDto(url: url, width: attachment.originalFile.width, height: attachment.originalFile.height),
                  smallFile: FileInfoDto(url: previewUrl, width: attachment.smallFile.width, height: attachment.smallFile.height),
                  originalHdrFile: originalHdrFile,
                  description: attachment.description,
                  blurhash: attachment.blurhash,
                  metadata: MetadataDto(exif: attachment.exif),
                  location: AttachmentDto.getLocation(location: attachment.location),
                  license: AttachmentDto.getLicense(license: attachment.license))
    }
    
    private static func getLocation(location: Location?) -> LocationDto? {
        guard let location else {
            return nil
        }
        
        return LocationDto(from: location)
    }
    
    private static func getLicense(license: License?) -> LicenseDto? {
        guard let license else {
            return nil
        }
        
        return LicenseDto(id: license.stringId(), name: license.name, code: license.code, description: nil, url: license.url)
    }
    
    private static func getOrginalHdrFile(attachment: Attachment, baseStoragePath: String) -> FileInfoDto? {
        if attachment.originalHdrFile == nil {
            return nil
        }
        
        guard let url = AttachmentDto.getOrginalHdrUrl(attachment: attachment, baseStoragePath: baseStoragePath) else {
            return nil
        }

        return FileInfoDto(url: url, width: attachment.originalFile.width, height: attachment.originalFile.height)
    }
    
    public static func getUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.originalFile.fileName
    }
    
    public static func getPreviewUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.smallFile.fileName
    }
    
    public static func getOrginalHdrUrl(attachment: Attachment, baseStoragePath: String) -> String? {
        guard let orginalHdrFile = attachment.originalHdrFile else {
            return nil
        }
        
        return baseStoragePath.finished(with: "/") + orginalHdrFile.fileName
    }
}

extension AttachmentDto: Content { }
