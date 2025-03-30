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
    init(from attachment: Attachment, baseImagesPath: String) {
        let url = AttachmentDto.getUrl(attachment: attachment, baseImagesPath: baseImagesPath)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseImagesPath: baseImagesPath)
        let originalHdrFile = AttachmentDto.getOrginalHdrFile(attachment: attachment, baseImagesPath: baseImagesPath)
        
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
    
    private static func getOrginalHdrFile(attachment: Attachment, baseImagesPath: String) -> FileInfoDto? {
        if attachment.originalHdrFile == nil {
            return nil
        }
        
        guard let url = AttachmentDto.getOrginalHdrUrl(attachment: attachment, baseImagesPath: baseImagesPath) else {
            return nil
        }

        return FileInfoDto(url: url, width: attachment.originalFile.width, height: attachment.originalFile.height)
    }
    
    public static func getUrl(attachment: Attachment, baseImagesPath: String) -> String {
        return baseImagesPath.finished(with: "/") + attachment.originalFile.fileName
    }
    
    public static func getPreviewUrl(attachment: Attachment, baseImagesPath: String) -> String {
        return baseImagesPath.finished(with: "/") + attachment.smallFile.fileName
    }
    
    public static func getOrginalHdrUrl(attachment: Attachment, baseImagesPath: String) -> String? {
        guard let orginalHdrFile = attachment.originalHdrFile else {
            return nil
        }
        
        return baseImagesPath.finished(with: "/") + orginalHdrFile.fileName
    }
}

extension AttachmentDto: Content { }
