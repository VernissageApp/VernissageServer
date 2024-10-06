//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SwiftGD

extension AttachmentsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("attachments")

    func boot(routes: RoutesBuilder) throws {
        let photosGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        photosGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.attachmentsCreate))
            .on(.POST, AttachmentsController.uri, body: .collect(maxSize: "20mb"), use: upload)

        photosGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.attachmentsUpdate))
            .put(AttachmentsController.uri, ":id", use: update)
        
        photosGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.attachmentsDelete))
            .delete(AttachmentsController.uri, ":id", use: delete)
        
        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsDescribe))
            .get(AttachmentsController.uri, ":id", "describe", use: describe)
        
        photosGroup
            .grouped(EventHandlerMiddleware(.attachmentsHashtags))
            .get(AttachmentsController.uri, ":id", "hashtags", use: hashtags)
    }
}

/// Controls basic operations for photos.
///
/// The controller allows you to manage photos when adding a new status. It is possible to add a new photo,
/// change or delete a previously uploaded one (unless the status has already been saved).
///
/// > Important: Base controller URL: `/api/v1/attachments`.
struct AttachmentsController {

    private struct AttachmentRequest: Content {
        var file: File
    }
    
    /// Upload new photo.
    ///
    /// Image files can be upladed to the server using the `multipart/form-data` encoding algorithm.
    /// In the [RFC7578](https://www.rfc-editor.org/rfc/rfc7578) you can find how to create
    /// that kind of the requests. Many frameworks supports that kind of the requests out of the box.
    ///
    /// > Important: Endpoint URL: `/api/v1/attachments`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/attachments" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -F 'file=@"/images/photo.png"'
    /// ```
    ///
    /// **Example request header:**
    ///
    /// ```
    /// Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryozM7tKuqLq2psuEB
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB
    /// Content-Disposition: form-data; name="file"; filename="photo.png"
    /// Content-Type: image/png
    ///
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB--
    /// [BINARY_DATA]
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333518540363030529",
    ///     "previewUrl": "https://s3.eu-central-1.amazonaws.com/vernissage-test/3503052249cd47d9a492544f4c767dbd.png",
    ///     "url": "https://s3.eu-central-1.amazonaws.com/vernissage-test/dd72a9d6d89645358b2bec3eaa52481b.png"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Basic information about uploaded image.
    ///
    /// - Throws: `AttachmentError.missingImage` if image is not attached into the request.
    /// - Throws: `AttachmentError.imageTooLarge` if image file is too large.
    /// - Throws: `AttachmentError.createResizedImageFailed` if cannot create image for resizing.
    /// - Throws: `AttachmentError.resizedImageFailed` if image cannot be resized.
    /// - Throws: `AttachmentError.savedFailed` if saving file failed.
    @Sendable
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
        guard let image = Image.create(path: tmpOriginalFileUrl) else {
            throw AttachmentError.createResizedImageFailed
        }
        
        // Read Exif orientation.
        let orientation = ImageOrientation(fileUrl: tmpOriginalFileUrl, on: request.application)

        // Rotate based on orientation.
        guard let rotatedImage = image.rotate(basedOn: orientation) else {
            throw AttachmentError.imageRotationFailed
        }
        
        // Export as a JPEG (without metadata).
        guard let exportedBinary = try? rotatedImage.export(as: ExportableFormat.jpg(quality: -1)),
              let exported = try? Image(data: exportedBinary) else {
            throw AttachmentError.imageResizeFailed
        }
        
        // Save exported image in temp folder.
        let tmpExportedFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: attachmentRequest.file.filename)
        exported.write(to: tmpExportedFileUrl, quality: Constants.imageQuality)
        
        // Resize image.
        guard let resized = rotatedImage.resizedTo(width: 800) else {
            throw AttachmentError.imageResizeFailed
        }
        
        // Save resized image in temp folder.
        let tmpSmallFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: attachmentRequest.file.filename)
        resized.write(to: tmpSmallFileUrl, quality: Constants.imageQuality)
        
        // Save exported image.
        guard let savedExportedFileName = try await storageService.save(fileName: attachmentRequest.file.filename,
                                                                        url: tmpExportedFileUrl,
                                                                        on: request) else {
            throw AttachmentError.savedFailed
        }
        
        // Save small image.
        guard let savedSmallFileName = try await storageService.save(fileName: attachmentRequest.file.filename,
                                                                     url: tmpSmallFileUrl,
                                                                     on: request) else {
            throw AttachmentError.savedFailed
        }

        // Prepare obejct to save in database.
        let exportedFileInfoId = request.application.services.snowflakeService.generate()
        let exportedFileInfo = FileInfo(id: exportedFileInfoId,
                                        fileName: savedExportedFileName,
                                        width: image.size.width,
                                        height: image.size.height)

        let smallFileInfoId = request.application.services.snowflakeService.generate()
        let smallFileInfo = FileInfo(id: smallFileInfoId,
                                     fileName: savedSmallFileName,
                                     width: resized.size.width,
                                     height: resized.size.height)

        let attachmentId = request.application.services.snowflakeService.generate()
        let attachment = try Attachment(id: attachmentId,
                                        userId: authorizationPayloadId,
                                        originalFileId: exportedFileInfo.requireID(),
                                        smallFileId: smallFileInfo.requireID())
        
        // Operation in database should be performed in one transaction.
        try await request.db.transaction { database in
            try await exportedFileInfo.save(on: database)
            try await smallFileInfo.save(on: database)
            try await attachment.save(on: database)
        }
                    
        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpOriginalFileUrl, on: request)
        try await temporaryFileService.delete(url: tmpExportedFileUrl, on: request)
        try await temporaryFileService.delete(url: tmpSmallFileUrl, on: request)
                
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        let temporaryAttachmentDto = TemporaryAttachmentDto(from: attachment,
                                                            originalFileName: savedExportedFileName,
                                                            smallFileName: savedSmallFileName,
                                                            baseStoragePath: baseStoragePath)
        
        return try await temporaryAttachmentDto.encodeResponse(status: .created, for: request)
    }

    /// Update photo.
    ///
    /// After the photo is correctly uploaded to the server, we receive its `id` number in response.
    /// This makes it possible to call this endpoint. With it, it is possible to change/add additional
    /// information about the photo, such as description, location, license or exif metadata.
    ///
    /// FIeld description:
    ///
    /// - `locationId` can be downloaded here: ``LocationsController/search(request:)``.
    /// - `licenseId` can be downloaded here: ``LicensesController/list(request:)``.
    /// - `blurhash` should be generate based on [BlurHash](https://github.com/woltapp/blurhash/blob/master/Algorithm.md) algorithm.
    ///
    /// > Important: Endpoint URL: `/api/v1/attachments/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/attachments/7333518540363030529" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "id": "7333524055101298689",
    ///     "description": "This is the cat.",
    ///     "blurhash": "U5C?r]~q00xu9F-;WBIU009F~q%M-;ayj[xu",
    ///     "make": "SONY",
    ///     "model": "ILCE-7M4",
    ///     "lens": "Zeiss Batis 1.8/85",
    ///     "createDate": "2022-10-20T14:24:51.037+02:00",
    ///     "focalLenIn35mmFilm": "85",
    ///     "fNumber": "f/8",
    ///     "exposureTime": "1/500",
    ///     "photographicSensitivity": "100",
    ///     "locationId": "7257110934739898369",
    ///     "licenseId": "7310942225159020545",
    ///     "latitude: "50,67211",
    ///     "longitude: "17,92533",
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if attachment not exists.
    @Sendable
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
                    exif.software = temporaryAttachmentDto.software
                    exif.film = temporaryAttachmentDto.film
                    exif.chemistry = temporaryAttachmentDto.chemistry
                    exif.scanner = temporaryAttachmentDto.scanner
                    exif.latitude = temporaryAttachmentDto.latitude
                    exif.longitude = temporaryAttachmentDto.longitude
                    
                    try await exif.save(on: database)
                } else {
                    try await exif.delete(on: database)
                }
            } else {
                if temporaryAttachmentDto.hasAnyMetadata() {
                    let newExifId = request.application.services.snowflakeService.generate()

                    let exif = Exif()
                    exif.id = newExifId
                    exif.make = temporaryAttachmentDto.make
                    exif.model = temporaryAttachmentDto.model
                    exif.lens = temporaryAttachmentDto.lens
                    exif.createDate = temporaryAttachmentDto.createDate
                    exif.focalLenIn35mmFilm = temporaryAttachmentDto.focalLenIn35mmFilm
                    exif.fNumber = temporaryAttachmentDto.fNumber
                    exif.exposureTime = temporaryAttachmentDto.exposureTime
                    exif.photographicSensitivity = temporaryAttachmentDto.photographicSensitivity
                    exif.software = temporaryAttachmentDto.software
                    exif.film = temporaryAttachmentDto.film
                    exif.chemistry = temporaryAttachmentDto.chemistry
                    exif.scanner = temporaryAttachmentDto.scanner
                    exif.latitude = temporaryAttachmentDto.latitude
                    exif.longitude = temporaryAttachmentDto.longitude
                    
                    try await attachment.$exif.create(exif, on: database)
                }
            }
            
            try await attachment.save(on: database)
        }
            
        return HTTPStatus.ok
    }
    
    /// Delete photo.
    ///
    /// When creating a status, users may mistakenly upload a different photo than they wanted.
    /// Use this endpoint to delete such a photo. Deleting a photo is possible only until the photo is not yet
    /// associated with the status, that is, until a new status is uploaded with the photo `id` attached.
    ///
    /// > Important: Endpoint URL: `/api/v1/attachments/:id`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/attachments/7333518540363030529" \
    /// -X DELETE \
    /// -H "Content-Type: application/json"
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if attachment not exists.
    /// - Throws: `EntityForbiddenError.attachmentForbidden` if access to attachment is forbidden.
    /// - Throws: `AttachmentError.attachmentAlreadyConnectedToStatus` if attachment already connected to status.
    @Sendable
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
    
    /// Generate description for the photo.
    ///
    /// Thanks to this endpoint we can use OpenAI to generate description
    /// about the image. This is especially usefull for people with vision problems.
    ///
    /// > Important: Endpoint URL: `/api/v1/attachments/:id/describe`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/attachments/7333518540363030529/describe" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: `AttachmentDescriptionDto` entity with image description.
    ///
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if attachment not exists.
    /// - Throws: `EntityForbiddenError.attachmentForbidden` if access to attachment is forbidden.
    /// - Throws: `AttachmentError.attachmentAlreadyConnectedToStatus` if attachment already connected to status.
    /// - Throws: `OpenAIError.openAIIsNotEnabled` if OpenAI is not enabled.
    /// - Throws: `OpenAIError.openAIIsNotConfigured` if OpenAI is not configured.
    @Sendable
    func describe(request: Request) async throws -> AttachmentDescriptionDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        let attachment = try await Attachment.query(on: request.db)
            .filter(\.$id == id)
            .filter(\.$user.$id == authorizationPayloadId)
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
        
        guard request.application.settings.cached?.isOpenAIEnabled == true else {
            throw OpenAIError.openAIIsNotEnabled
        }
        
        guard let openAIKey = request.application.settings.cached?.openAIKey else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard openAIKey.count > 0 else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard let openAIModel = request.application.settings.cached?.openAIModel else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard openAIModel.count > 0 else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        let openAIService = request.application.services.openAIService
        let storageService = request.application.services.storageService
        
        let baseStoragePath = storageService.getBaseStoragePath(on: request.application)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        
        let description = try await openAIService.generateImageDescription(imageUrl: previewUrl, model: openAIModel, apiKey: openAIKey)
        return AttachmentDescriptionDto(description: description)
    }
    
    /// Generate hashtags for the photo.
    ///
    /// Thanks to this endpoint we can use OpenAI to generate hashtags
    /// about the image.
    ///
    /// > Important: Endpoint URL: `/api/v1/attachments/:id/hashtags`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/attachments/7333518540363030529/hashtags" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: `AttachmentHashtagDto` entity with image description.
    ///
    /// - Throws: `EntityNotFoundError.attachmentNotFound` if attachment not exists.
    /// - Throws: `EntityForbiddenError.attachmentForbidden` if access to attachment is forbidden.
    /// - Throws: `AttachmentError.attachmentAlreadyConnectedToStatus` if attachment already connected to status.
    /// - Throws: `OpenAIError.openAIIsNotEnabled` if OpenAI is not enabled.
    /// - Throws: `OpenAIError.openAIIsNotConfigured` if OpenAI is not configured.
    @Sendable
    func hashtags(request: Request) async throws -> AttachmentHashtagDto {
        guard let authorizationPayloadId = request.userId else {
            throw Abort(.forbidden)
        }
        
        guard let id = request.parameters.get("id", as: Int64.self) else {
            throw Abort(.badRequest)
        }
        
        let attachment = try await Attachment.query(on: request.db)
            .filter(\.$id == id)
            .filter(\.$user.$id == authorizationPayloadId)
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
        
        guard request.application.settings.cached?.isOpenAIEnabled == true else {
            throw OpenAIError.openAIIsNotEnabled
        }
        
        guard let openAIKey = request.application.settings.cached?.openAIKey else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard openAIKey.count > 0 else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard let openAIModel = request.application.settings.cached?.openAIModel else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        guard openAIModel.count > 0 else {
            throw OpenAIError.openAIIsNotConfigured
        }
        
        let openAIService = request.application.services.openAIService
        let storageService = request.application.services.storageService
        
        let baseStoragePath = storageService.getBaseStoragePath(on: request.application)
        let previewUrl = AttachmentDto.getPreviewUrl(attachment: attachment, baseStoragePath: baseStoragePath)
        
        let hashtags = try await openAIService.generateHashtags(imageUrl: previewUrl, model: openAIModel, apiKey: openAIKey)
        return AttachmentHashtagDto(hashtags: hashtags)
    }
}
