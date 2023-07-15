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
            .put(AttachmentsController.uri, ":id", use: update)
        
        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsDelete))
            .delete(AttachmentsController.uri, ":id", use: delete)
    }

    /// Upload new photo.
    func upload(request: Request) async throws -> Response {
        guard let attachmentRequest = try? request.content.decode(AttachmentRequest.self) else {
            throw AvatarError.missingImage
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.badRequest)
        }

        let temporaryFileService = request.application.services.temporaryFileService
        let storageService = request.application.services.storageService
        
        // Save image to temp folder.
        let tmpOriginalFileUrl = try await temporaryFileService.save(fileName: attachmentRequest.file.filename,
                                                                     byteBuffer: attachmentRequest.file.data,
                                                                     on: request)
        
        // Create image in the memory.
        guard let image = Image(url: tmpOriginalFileUrl) else {
            throw AvatarError.createResizedImageFailed
        }
        
        // Resize image.
        guard let resized = image.resizedTo(width: 800) else {
            throw AvatarError.resizedImageFailed
        }
        
        // Save resized image in temp folder.
        let tmpSmallFileUrl = try temporaryFileService.temporaryPath(on: request, based: attachmentRequest.file.filename)
        resized.write(to: tmpSmallFileUrl)
        
        // Save original image.
        guard let savedOriginalFileName = try await storageService.save(fileName: attachmentRequest.file.filename, url: tmpOriginalFileUrl, on: request) else {
            throw AvatarError.savedFailed
        }
        
        // Save small image.
        guard let savedSmallFileName = try await storageService.save(fileName: attachmentRequest.file.filename, url: tmpSmallFileUrl, on: request) else {
            throw AvatarError.savedFailed
        }
        
        let attachment = Attachment(userId: authorizationPayloadId,
                                    originalFileName: savedOriginalFileName,
                                    smallFileName: savedSmallFileName,
                                    originalWidth: image.size.width,
                                    originalHeight: image.size.height,
                                    smallWidth: resized.size.width,
                                    smallHeight: resized.size.height)

        try await attachment.save(on: request.db)
                        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request)
        let temporaryAttachmentDto = TemporaryAttachmentDto(from: attachment, baseStoragePath: baseStoragePath)

        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpOriginalFileUrl, on: request)
        try await temporaryFileService.delete(url: tmpSmallFileUrl, on: request)
        
        return try await temporaryAttachmentDto.encodeResponse(status: .created, for: request)
    }

    /// Update photo.
    func update(request: Request) async throws -> HTTPStatus {
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        guard let temporaryAttachmentDto = try? request.content.decode(TemporaryAttachmentDto.self) else {
            throw AvatarError.missingImage
        }
        
        guard let attachment = try await Attachment.find(id, on: request.db) else {
            throw EntityNotFoundError.attachmentNotFound
        }
        
        attachment.blurhash = temporaryAttachmentDto.blurhash
        attachment.description = temporaryAttachmentDto.description
        
        if temporaryAttachmentDto.hasAnyMetadata() {
            let exifFromDatabase = try await self.getExifEntity(attachment: attachment, request: request)
            exifFromDatabase.make = temporaryAttachmentDto.make
            exifFromDatabase.model = temporaryAttachmentDto.model
            exifFromDatabase.lens = temporaryAttachmentDto.lens
            exifFromDatabase.createDate = temporaryAttachmentDto.createDate
            exifFromDatabase.focalLenIn35mmFilm = temporaryAttachmentDto.focalLenIn35mmFilm
            exifFromDatabase.fNumber = temporaryAttachmentDto.fNumber
            exifFromDatabase.exposureTime = temporaryAttachmentDto.exposureTime
            exifFromDatabase.photographicSensitivity = temporaryAttachmentDto.photographicSensitivity
        } else {
            if attachment.exif != nil {
                try await attachment.exif?.delete(on: request.db)
                attachment.exif = nil
            }
        }
        
        try await attachment.save(on: request.db)
        return HTTPStatus.ok
    }
    
    /// Delete photo.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        guard let attachment = try await Attachment.find(id, on: request.db) else {
            throw EntityNotFoundError.attachmentNotFound
        }
        
        try await attachment.delete(on: request.db)
        
        return HTTPStatus.ok
    }
    
    private func getExifEntity(attachment: Attachment, request: Request) async throws -> Exif {
        if let exif = attachment.exif {
            return exif
        }
        
        let exif = Exif()
        try await attachment.$exif.create(exif, on: request.db)
        
        return exif
    }
}
