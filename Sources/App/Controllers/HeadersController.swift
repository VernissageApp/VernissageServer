//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import SwiftGD

/// Controls basic operations for headers image for user object.
final class HeadersController: RouteCollection {

    public static let uri: PathComponent = .constant("headers")
    
    private struct Header: Content {
        var file: File
    }
    
    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped(HeadersController.uri)
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        usersGroup
            .grouped(EventHandlerMiddleware(.headerUpdate))
            .on(.POST, ":name", body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.headerDelete))
            .delete(":name", use: delete)
    }

    /// Update user's header image.
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
        
        // Resize image.
        guard let resized = image.resizedTo(width: 1500, height: 500) else {
            throw HeaderError.resizedImageFailed
        }
        
        // Save resized image.
        let resizedTmpFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: header.file.filename)
        resized.write(to: resizedTmpFileUrl)
        
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
