//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controls basic operations for avatar image for user object.
final class AvatarsController: RouteCollection {

    public static let uri: PathComponent = .constant("avatar")
    
    private struct Avatar: Content {
        var file: File
    }
    
    func boot(routes: RoutesBuilder) throws {
        let usersGroup = routes
            .grouped("api")
            .grouped("v1")
            .grouped("users")
            .grouped(":name")
            .grouped(UserAuthenticator())
            .grouped(UserPayload.guardMiddleware())
        
        usersGroup
            .grouped(EventHandlerMiddleware(.avatarUpdate))
            .on(.POST, AvatarsController.uri, body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.avatarDelete))
            .delete(AvatarsController.uri, use: delete)
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
        
        guard let userFromDb = try await usersService.get(on: request, userName: request.userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }

        guard let avatar = try? request.content.decode(Avatar.self) else {
            throw AvatarError.missingImage
        }
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        guard let savedFileName = try await storageService.save(fileName: avatar.file.filename, byteBuffer: avatar.file.data, on: request) else {
            throw AvatarError.savedFailed
        }
        
        userFromDb.avatarFileName = savedFileName
        try await userFromDb.save(on: request.db)
        
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
        
        guard let userFromDb = try await usersService.get(on: request, userName: request.userNameNormalized) else {
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
