//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import SwiftGD

extension AvatarsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("avatars")

    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(AvatarsController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        usersGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.avatarUpdate))
            .grouped(CacheControlMiddleware(.noStore))
            .on(.POST, ":name", body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.avatarDelete))
            .grouped(CacheControlMiddleware(.noStore))
            .delete(":name", use: delete)
    }
}

/// Controls basic operations for avatar image for user object.
///
/// With this controller, the user can change his avatar in the system. He can add, overwrite or delete the existing one.
///
/// > Important: Base controller URL: `/api/v1/avatars`.
struct AvatarsController {
    
    private struct Avatar: Content {
        var file: File
    }

    /// Update user's avatar.
    ///
    /// Avatar files can be upladed to the server using the `multipart/form-data` encoding algorithm.
    /// In the [RFC7578](https://www.rfc-editor.org/rfc/rfc7578) you can find how to create
    /// that kind of the requests. Many frameworks supports that kind of the requests out of the box.
    ///
    /// > Important: Endpoint URL: `/api/v1/avatars`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/avatars" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -F 'file=@"/images/avatar.png"'
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
    /// Content-Disposition: form-data; name="file"; filename="avatar.png"
    /// Content-Type: image/png
    ///
    /// ------WebKitFormBoundaryozM7tKuqLq2psuEB--
    /// [BINARY_DATA]
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityForbiddenError.userForbidden` if access to specified user is forbidden.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `AvatarError.missingImage` if image is not attached into the request.
    /// - Throws: `AvatarError.createResizedImageFailed` if cannot create image for resizing.
    /// - Throws: `AvatarError.resizedImageFailed` if image cannot be resized.
    @Sendable
    func update(request: Request) async throws -> HTTPStatus {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        guard usersService.isSignedInUser(userName: userName, on: request) else {
            throw EntityForbiddenError.userForbidden
        }
        
        guard let userFromDb = try await usersService.get(userName: request.userNameNormalized, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }

        guard let avatar = try? request.content.decode(Avatar.self) else {
            throw AvatarError.missingImage
        }
        

        // Save image to temp folder.
        let temporaryFileService = request.application.services.temporaryFileService
        let tmpFileUrl = try await temporaryFileService.save(fileName: avatar.file.filename,
                                                             byteBuffer: avatar.file.data,
                                                             on: request.executionContext)

        // Create image in the memory.
        guard let image = Image.create(path: tmpFileUrl) else {
            throw AvatarError.createResizedImageFailed
        }
        
        // Read Exif orientation.
        let orientation = ImageOrientation(fileUrl: tmpFileUrl, on: request.application)

        // Rotate based on orientation.
        guard let rotatedImage = image.rotate(basedOn: orientation) else {
            throw AttachmentError.imageRotationFailed
        }
        
        // Resize image.
        guard let resized = rotatedImage.resizedTo(width: 600, height: 600) else {
            throw AvatarError.resizedImageFailed
        }
        
        // Save resized image.
        let resizedTmpFileUrl = try temporaryFileService.temporaryPath(based: avatar.file.filename, on: request.executionContext)
        resized.write(to: resizedTmpFileUrl, quality: Constants.imageQuality)
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        let savedFileName = try await storageService.save(fileName: avatar.file.filename,
                                                          url: resizedTmpFileUrl,
                                                          on: request.executionContext)
        
        userFromDb.avatarFileName = savedFileName
        try await userFromDb.save(on: request.db)
        
        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpFileUrl, on: request.executionContext)
        try await temporaryFileService.delete(url: resizedTmpFileUrl, on: request.executionContext)
        
        return HTTPStatus.ok
    }

    /// Delete user's avatar.
    ///
    /// The endpoint is used to remove the user's avatar when the user doesn't want any of their images.
    ///
    /// > Important: Endpoint URL: `/api/v1/avatars`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/avatars" \
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
    /// - Throws: `EntityForbiddenError.userForbidden` if access to specified user is forbidden.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `AvatarError.notFound` if user doesn't have any avatar.
    @Sendable
    func delete(request: Request) async throws -> HTTPStatus {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        guard usersService.isSignedInUser(userName: userName, on: request) else {
            throw EntityForbiddenError.userForbidden
        }
        
        guard let userFromDb = try await usersService.get(userName: request.userNameNormalized, on: request.db) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let avatarFileName = userFromDb.avatarFileName else {
            throw AvatarError.notFound
        }
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        try await storageService.delete(fileName: avatarFileName, on: request.executionContext)
        
        // Delete user's avatar.
        userFromDb.avatarFileName = nil
        try await userFromDb.save(on: request.db)
        
        return HTTPStatus.ok
    }
}
