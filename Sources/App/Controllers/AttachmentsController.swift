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
            .on(.POST, AttachmentsController.uri, body: .collect(maxSize: "20mb"), use: upload)

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
            throw AttachmentError.missingImage
        }
        
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        let appplicationSettings = request.application.settings.cached
        guard attachmentRequest.file.data.readableBytes < (appplicationSettings?.imageSizeLimit ?? 10_485_760) else {
            throw AttachmentError.imageTooLarge
        }

        let temporaryFileService = request.application.services.temporaryFileService
        let storageService = request.application.services.storageService
        
        // Save image to temp folder.
        let tmpOriginalFileUrl = try await temporaryFileService.save(fileName: attachmentRequest.file.filename,
                                                                     byteBuffer: attachmentRequest.file.data,
                                                                     on: request)
        
        // Create image in the memory.
        guard let image = Image(url: tmpOriginalFileUrl) else {
            throw AttachmentError.createResizedImageFailed
        }
        
        // Resize image.
        guard let resized = image.resizedTo(width: 800) else {
            throw AttachmentError.resizedImageFailed
        }
        
        // Save resized image in temp folder.
        let tmpSmallFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: attachmentRequest.file.filename)
        resized.write(to: tmpSmallFileUrl)
        
        // Save original image.
        guard let savedOriginalFileName = try await storageService.save(fileName: attachmentRequest.file.filename, url: tmpOriginalFileUrl, on: request) else {
            throw AttachmentError.savedFailed
        }
        
        // Save small image.
        guard let savedSmallFileName = try await storageService.save(fileName: attachmentRequest.file.filename, url: tmpSmallFileUrl, on: request) else {
            throw AttachmentError.savedFailed
        }

        // Prepare obejct to save in database.
        let originalFileInfo = FileInfo(fileName: savedOriginalFileName, width: image.size.width, height: image.size.height)
        let smallFileInfo = FileInfo(fileName: savedSmallFileName, width: resized.size.width, height: resized.size.height)
        let attachment = try Attachment(userId: authorizationPayloadId,
                                        originalFileId: originalFileInfo.requireID(),
                                        smallFileId: smallFileInfo.requireID())
        
        // Operation in database should be performed in one transaction.
        try await request.db.transaction { database in
            try await originalFileInfo.save(on: database)
            try await smallFileInfo.save(on: database)
            try await attachment.save(on: database)
        }
                    
        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpOriginalFileUrl, on: request)
        try await temporaryFileService.delete(url: tmpSmallFileUrl, on: request)
                
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let temporaryAttachmentDto = TemporaryAttachmentDto(from: attachment,
                                                            originalFileName: savedOriginalFileName,
                                                            smallFileName: savedSmallFileName,
                                                            baseStoragePath: baseStoragePath)
        
        return try await temporaryAttachmentDto.encodeResponse(status: .created, for: request)
    }

    /// Update photo.
    func update(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        guard let temporaryAttachmentDto = try? request.content.decode(TemporaryAttachmentDto.self) else {
            throw Abort(.badRequest)
        }
        
        let attachment = try await Attachment.query(on: request.db)
            .filter(\.$id == id)
            .filter(\.$user.$id == authorizationPayloadId)
            .first()
        
        guard let attachment else {
            throw EntityNotFoundError.attachmentNotFound
        }
        
        try TemporaryAttachmentDto.validate(content: request)
        
        // Operation in database should be performed in one transaction.
        try await request.db.transaction { database in
            attachment.blurhash = temporaryAttachmentDto.blurhash
            attachment.description = temporaryAttachmentDto.description
            attachment.$location.id = temporaryAttachmentDto.locationId?.toId()
            attachment.$license.id = temporaryAttachmentDto.licenseId?.toId()
            
            if let exif = try await attachment.$exif.query(on: database).first() {
                if temporaryAttachmentDto.hasAnyMetadata() {
                    exif.make = temporaryAttachmentDto.make
                    exif.model = temporaryAttachmentDto.model
                    exif.lens = temporaryAttachmentDto.lens
                    exif.createDate = temporaryAttachmentDto.createDate
                    exif.focalLenIn35mmFilm = temporaryAttachmentDto.focalLenIn35mmFilm
                    exif.fNumber = temporaryAttachmentDto.fNumber
                    exif.exposureTime = temporaryAttachmentDto.exposureTime
                    exif.photographicSensitivity = temporaryAttachmentDto.photographicSensitivity
                    
                    try await exif.save(on: database)
                } else {
                    try await exif.delete(on: database)
                }
            } else {
                if temporaryAttachmentDto.hasAnyMetadata() {
                    let exif = Exif()
                    exif.make = temporaryAttachmentDto.make
                    exif.model = temporaryAttachmentDto.model
                    exif.lens = temporaryAttachmentDto.lens
                    exif.createDate = temporaryAttachmentDto.createDate
                    exif.focalLenIn35mmFilm = temporaryAttachmentDto.focalLenIn35mmFilm
                    exif.fNumber = temporaryAttachmentDto.fNumber
                    exif.exposureTime = temporaryAttachmentDto.exposureTime
                    exif.photographicSensitivity = temporaryAttachmentDto.photographicSensitivity
                    
                    try await attachment.$exif.create(exif, on: database)
                }
            }
            
            try await attachment.save(on: database)
        }
            
        return HTTPStatus.ok
    }
    
    /// Delete photo.
    func delete(request: Request) async throws -> HTTPStatus {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        let attachment = try await Attachment.query(on: request.db)
            .filter(\.$id == id)
            .filter(\.$user.$id == authorizationPayloadId)
            .with(\.$exif)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .first()
        
        guard let attachment else {
            throw EntityNotFoundError.attachmentNotFound
        }
        
        guard attachment.$user.id == authorizationPayloadId else {
            throw EntityForbiddenError.attachmentForbidden
        }
        
        if attachment.$status.id != nil {
            throw AttachmentError.attachmentAlreadyConnectedToStatus
        }
        
        try await request.db.transaction { database in
            try await attachment.exif?.delete(on: database)
            try await attachment.delete(on: database)
            try await attachment.originalFile.delete(on: database)
            try await attachment.smallFile.delete(on: database)
        }
        
        return HTTPStatus.ok
    }
}
