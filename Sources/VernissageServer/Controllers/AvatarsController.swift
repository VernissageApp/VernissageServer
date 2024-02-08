//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
            .grouped(EventHandlerMiddleware(.avatarUpdate))
            .on(.POST, ":name", body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.avatarDelete))
            .delete(":name", use: delete)
    }
}

/// Controls basic operations for avatar image for user object.
final class AvatarsController {
    
    private struct Avatar: Content {
        var file: File
    }

    /// Update user's avatar.
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

        guard let avatar = try? request.content.decode(Avatar.self) else {
            throw AvatarError.missingImage
        }
        

        // Save image to temp folder.
        let temporaryFileService = request.application.services.temporaryFileService
        let tmpFileUrl = try await temporaryFileService.save(fileName: avatar.file.filename,
                                                             byteBuffer: avatar.file.data,
                                                             on: request)

        // Create image in the memory.
        guard let image = Image(url: tmpFileUrl) else {
            throw AvatarError.createResizedImageFailed
        }
        
        // Resize image.
        guard let resized = image.resizedTo(width: 600, height: 600) else {
            throw AvatarError.resizedImageFailed
        }
        
        // Save resized image.
        let resizedTmpFileUrl = try temporaryFileService.temporaryPath(on: request.application, based: avatar.file.filename)
        resized.write(to: resizedTmpFileUrl)
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        guard let savedFileName = try await storageService.save(fileName: avatar.file.filename, url: resizedTmpFileUrl, on: request) else {
            throw AvatarError.savedFailed
        }
        
        userFromDb.avatarFileName = savedFileName
        try await userFromDb.save(on: request.db)
        
        // Remove temporary files.
        try await temporaryFileService.delete(url: tmpFileUrl, on: request)
        try await temporaryFileService.delete(url: resizedTmpFileUrl, on: request)
        
        return HTTPStatus.ok
    }

    /// Delete user's avatar.
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
        
        guard let avatarFileName = userFromDb.avatarFileName else {
            throw AvatarError.notFound
        }
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        try await storageService.delete(fileName: avatarFileName, on: request)
        
        // Delete user's avatar.
        userFromDb.avatarFileName = nil
        try await userFromDb.save(on: request.db)
        
        return HTTPStatus.ok
    }
}
