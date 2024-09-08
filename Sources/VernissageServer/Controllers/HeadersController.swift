//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import SwiftGD

extension HeadersController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("headers")

    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(HeadersController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        usersGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.headerUpdate))
            .on(.POST, ":name", body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(XsrfTokenValidatorMiddleware())
            .grouped(EventHandlerMiddleware(.headerDelete))
            .delete(":name", use: delete)
    }
}

/// Controls basic operations for headers image for user object.
///
/// With this controller, the user can change his header in the system. He can add, overwrite or delete the existing one.
///
/// > Important: Base controller URL: `/api/v1/headers`.
final class HeadersController {
    
    private struct Header: Content {
        var file: File
    }
    
    /// Update user's header image.
    ///
    /// Headers files can be upladed to the server using the `multipart/form-data` encoding algorithm.
    /// In the [RFC7578](https://www.rfc-editor.org/rfc/rfc7578) you can find how to create
    /// that kind of the requests. Many frameworks supports that kind of the requests out of the box.
    ///
    /// > Important: Endpoint URL: `/api/v1/headers`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/headers" \
    /// -X POST \
    /// -H "Authorization: Bearer [ACCESS_TOKEN]" \
    /// -F 'file=@"/images/header.png"'
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
    /// Content-Disposition: form-data; name="file"; filename="header.png"
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
    /// - Throws: `HeaderError.missingImage` if image is not attached into the request.
    /// - Throws: `HeaderError.createResizedImageFailed` if cannot create image for resizing.
    /// - Throws: `HeaderError.resizedImageFailed` if image cannot be resized.
    /// - Throws: `HeaderError.savedFailed` if saving file failed.
    func update(request: Request) async throws -> HTTPStatus {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        guard usersService.isSignedInUser(on: request, userName: userName) else {
            throw EntityForbiddenError.userForbidden
        }
        
        guard let userFromDb = try await usersService.get(on: request.db, userName: request.userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }

        guard let header = try? request.content.decode(Header.self) else {
            throw HeaderError.missingImage
        }
        
        // Save image to temp folder.
        let temporaryFileService = request.application.services.temporaryFileService
        let tmpFileUrl = try await temporaryFileService.save(fileName: header.file.filename,
                                                             byteBuffer: header.file.data,
                                                             on: request)

        // Create image in the memory.
        guard let image = Image(url: tmpFileUrl) else {
            throw HeaderError.createResizedImageFailed
        }
        
        // Read Exif orientation.
        let orientation = ImageOrientation(fileUrl: tmpFileUrl, on: request.application)

        // Rotate based on orientation.
        guard let rotatedImage = image.rotate(basedOn: orientation) else {
            throw AttachmentError.imageRotationFailed
        }
        
        // Resize image.
        guard let resized = rotatedImage.resizedTo(width: 1500, height: 500) else {
            throw HeaderError.resizedImageFailed
        }
        
        // Save resized image.
        let resizedTmpFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: header.file.filename)
        resized.write(to: resizedTmpFileUrl, quality: Constants.imageQuality)
        
        // Update user's header.
        let storageService = request.application.services.storageService
        guard let savedFileName = try await storageService.save(fileName: header.file.filename, url: resizedTmpFileUrl, on: request) else {
            throw HeaderError.savedFailed
        }
        
        userFromDb.headerFileName = savedFileName
        try await userFromDb.save(on: request.db)
        
        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpFileUrl, on: request)
        try await temporaryFileService.delete(url: resizedTmpFileUrl, on: request)
        
        return HTTPStatus.ok
    }

    /// Delete user's header image.
    ///
    /// The endpoint is used to remove the user's header when the user doesn't want any of their images.
    ///
    /// > Important: Endpoint URL: `/api/v1/headers`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/headers" \
    /// -X DELETE \
    /// -H "Content-Type: application/json"
    /// -H "Authorization: Bearer [ACCESS_TOKEN]"
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status.
    ///
    /// - Throws: `EntityForbiddenError.userForbidden` if access to specified user is forbidden.
    /// - Throws: `EntityNotFoundError.userNotFound` if user not exists.
    /// - Throws: `HeaderError.notFound` if user doesn't have any header.
    func delete(request: Request) async throws -> HTTPStatus {

        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        guard usersService.isSignedInUser(on: request, userName: userName) else {
            throw EntityForbiddenError.userForbidden
        }
        
        guard let userFromDb = try await usersService.get(on: request.db, userName: request.userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }
        
        guard let headerFileName = userFromDb.headerFileName else {
            throw HeaderError.notFound
        }
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        try await storageService.delete(fileName: headerFileName, on: request)
        
        // Delete user's avatar.
        userFromDb.headerFileName = nil
        try await userFromDb.save(on: request.db)
        
        return HTTPStatus.ok
    }
}
