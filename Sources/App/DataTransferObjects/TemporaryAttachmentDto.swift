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
    var locationId: String?
}

extension TemporaryAttachmentDto {
    init(from attachment: Attachment, originalFileName: String, smallFileName: String, baseStoragePath: String) {
        self.init(id: attachment.stringId(),
                  url: baseStoragePath.finished(with: "/") + originalFileName,
                  previewUrl: baseStoragePath.finished(with: "/") + smallFileName)
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
