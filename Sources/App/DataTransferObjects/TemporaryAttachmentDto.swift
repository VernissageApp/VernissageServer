//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct TemporaryAttachmentDto {
    var id: String?
    var url: String
    var previewUrl: String
    var description: String?
    var blurhash: String?
    var make: String?
    var model: String?
    var lens: String?
    var createDate: String?
    var focalLenIn35mmFilm: String?
    var fNumber: String?
    var exposureTime: String?
    var photographicSensitivity: String?
}

extension TemporaryAttachmentDto {
    init(from attachment: Attachment, baseStoragePath: String) {
        let url = TemporaryAttachmentDto.getUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        let previewUrl = TemporaryAttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        
        self.init(id: attachment.stringId(),
                  url: url,
                  previewUrl: previewUrl)
    }
    
    private static func getUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.originalFileName
    }
    
    private static func getPreviewUrl(attachment: Attachment, baseStoragePath: String) -> String {
        return baseStoragePath.finished(with: "/") + attachment.smallFileName
    }
}

extension TemporaryAttachmentDto: Content { }

extension TemporaryAttachmentDto {
    public func hasAnyMetadata() -> Bool {
        make != nil ||
        model != nil ||
        lens != nil ||
        createDate != nil ||
        focalLenIn35mmFilm != nil ||
        fNumber != nil ||
        exposureTime != nil ||
        photographicSensitivity != nil
    }
}
