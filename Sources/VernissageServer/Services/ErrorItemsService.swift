//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ErroItemsServiceKey: StorageKey {
        typealias Value = ErroItemsServiceType
    }

    var errorItemsService: ErroItemsServiceType {
        get {
            self.application.storage[ErroItemsServiceKey.self] ?? ErroItemsService()
        }
        nonmutating set {
            self.application.storage[ErroItemsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ErroItemsServiceType: Sendable {
    func add(_ message: String, _ error: Error?, on application: Application) async
    func add(message: String, error: Error?, on application: Application) async
    
    func clear(on database: Database) async throws
}

/// A service for managing errors recorded by the system.
final class ErroItemsService: ErroItemsServiceType {
    func add(message: String, error: Error?, on application: Application) async {
        await self.add(message, error, on: application)
    }

    func add(_ message: String, _ error: Error? = nil, on application: Application) async {
        let snowflakeService = application.services.snowflakeService
        let newId = snowflakeService.generate()
        let code = String.createRandomString(length: 10)

        let errorMessage = error.debugDescription
        let errorItem = ErrorItem(id: newId,
                                  code: code,
                                  message: message,
                                  exception: errorMessage,
                                  userAgent: nil,
                                  clientVersion: nil,
                                  serverVersion: Constants.version)

        try? await errorItem.save(on: application.db)
    }
    
    func clear(on database: Database) async throws {
        let weekAgo = Date.weekAgo

        try await  ErrorItem.query(on: database)
            .filter(\.$createdAt < weekAgo)
            .delete()
    }
}
