//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
    var licenseId: String?
}

extension TemporaryAttachmentDto {
    init(from attachment: Attachment, originalFileName: String, smallFileName: String, baseStoragePath: String) {
        self.init(id: attachment.stringId(),
                  url: baseStoragePath.finished(with: "/") + originalFileName,
                  previewUrl: baseStoragePath.finished(with: "/") + smallFileName)
    }
}

extension TemporaryAttachmentDto: Content { }

extension TemporaryAttachmentDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("description", as: String?.self, is: .count(...2000) || .nil, required: false)
        validations.add("blurhash", as: String?.self, is: .count(...100) || .nil, required: false)
        validations.add("make", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("model", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("lens", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("createDate", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("focalLenIn35mmFilm", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("fNumber", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("exposureTime", as: String?.self, is: .count(...50) || .nil, required: false)
        validations.add("photographicSensitivity", as: String?.self, is: .count(...50) || .nil, required: false)
    }
}

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
