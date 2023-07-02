//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Controls basic operations for headers image for user object.
final class HeadersController: RouteCollection {

    public static let uri: PathComponent = .constant("header")
    
    private struct Header: Content {
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
            .grouped(EventHandlerMiddleware(.headerUpdate))
            .on(.POST, HeadersController.uri, body: .collect(maxSize: "2mb"), use: update)
        
        usersGroup
            .grouped(EventHandlerMiddleware(.headerDelete))
            .delete(HeadersController.uri, use: delete)
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
        
        guard let userFromDb = try await usersService.get(on: request, userName: request.userNameNormalized) else {
            throw EntityNotFoundError.userNotFound
        }

        guard let header = try? request.content.decode(Header.self) else {
            throw HeaderError.missingImage
        }
        
        // TODO: Resize header file (1500x500).
        
        // Update user's avatar.
        let storageService = request.application.services.storageService
        guard let savedFileName = try await storageService.save(fileName: header.file.filename, byteBuffer: header.file.data, on: request) else {
            throw HeaderError.savedFailed
        }
        
        userFromDb.headerFileName = savedFileName
        try await userFromDb.save(on: request.db)
        
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
        
        guard let userFromDb = try await usersService.get(on: request, userName: request.userNameNormalized) else {
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
