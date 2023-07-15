//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SwiftGD

/// Controls basic operations for photos.
final class AttachmentsController: RouteCollection {

    public static let uri: PathComponent = .constant("attachments")
    
    private struct AttachmentRequest: Content {
        var file: File
        var blurhash: String?
    }
    
    func boot(routes: RoutesBuilder) throws {
        let photosGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsCreate))
            .on(.POST, AttachmentsController.uri, body: .collect(maxSize: "6mb"), use: upload)

        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsUpdate))
            .delete(AttachmentsController.uri, use: update)
        
        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsDelete))
            .delete(AttachmentsController.uri, use: delete)
    }

    /// Upload new photo.
    func upload(request: Request) async throws -> Response {
        guard var attachmentRequest = try? request.content.decode(AttachmentRequest.self) else {
            throw AvatarError.missingImage
        }
                
        guard let attachmentData = attachmentRequest.file.data.readData(length: attachmentRequest.file.data.readableBytes) else {
            throw AvatarError.missingImage
        }
        
        // Create image in the memory.
        guard let image = try? Image(data: attachmentData) else {
            throw AvatarError.createResizedImageFailed
        }
        
        let attachment = Attachment(fileName: attachmentRequest.file.filename,
                                    fileSize: attachmentData.count,
                                    description: nil,
                                    blurhash: attachmentRequest.blurhash,
                                    originalWidth: image.size.width,
                                    originalHeight: image.size.height,
                                    smallWidth: image.size.width / 2,
                                    smallHeight: image.size.height / 2)

        try await attachment.save(on: request.db)
        
        let exif = self.getExif(photoData: attachmentData)
        if let exif {
            try await attachment.$exif.create(exif, on: request.db)
        }
                
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
        let attachmentDto = AttachmentDto(from: attachment, exif: exif, baseStoragePath: baseStoragePath)

        return try await attachmentDto.encodeResponse(status: .created, for: request)
    }

    /// Update photo.
    func update(request: Request) async throws -> HTTPStatus {
        return HTTPStatus.ok
    }
    
    /// Delete photo.
    func delete(request: Request) async throws -> HTTPStatus {
        return HTTPStatus.ok
    }
        
    private func getExif(photoData: Data?) -> Exif? {
        guard let exifProperties = photoData?.getExifData() else {
            return nil
        }
        
        let exif = Exif()

        if let make = exifProperties.getExifValue("Make") {
            exif.make = make
        }
        
        if let model = exifProperties.getExifValue("Model") {
            exif.model = model
        }

        if let lens = exifProperties.getExifValue("Lens") {
            exif.lens = lens
        }

        if let createDate = exifProperties.getExifValue("CreateDate") {
            exif.createDate = createDate
        }

        if let focalLenIn35mmFilm = exifProperties.getExifValue("FocalLenIn35mmFilm") {
            exif.focalLenIn35mmFilm = focalLenIn35mmFilm
        }
        
        if let fNumber = exifProperties.getExifValue("FNumber")?.calculateExifNumber() {
            exif.fNumber = fNumber
        }
        
        if let exposureTime = exifProperties.getExifValue("ExposureTime") {
            exif.exposureTime = exposureTime
        }
        
        if let photographicSensitivity = exifProperties.getExifValue("PhotographicSensitivity") {
            exif.photographicSensitivity = photographicSensitivity
        }
        
        return exif.hasAnyMetadata() ? exif : nil
    }
}
