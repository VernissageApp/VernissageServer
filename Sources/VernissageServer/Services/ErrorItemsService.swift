//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ErrorItemsServiceKey: StorageKey {
        typealias Value = ErrorItemsServiceType
    }

    var errorItemsService: ErrorItemsServiceType {
        get {
            self.application.storage[ErrorItemsServiceKey.self] ?? ErrorItemsService()
        }
        nonmutating set {
            self.application.storage[ErrorItemsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ErrorItemsServiceType: Sendable {
    /// Records a new error item with the provided message and error, storing it in the system for later review.
    ///
    /// - Parameters:
    ///   - message: The message describing the error or event.
    ///   - error: The associated error object, if any.
    ///   - application: The application context used for storing the error.
    /// - Note: This method is asynchronous and does not throw errors.
    func add(_ message: String, _ error: Error?, on application: Application) async

    /// Records a new error item with a specific message and error, storing it in the system for later review.
    ///
    /// - Parameters:
    ///   - message: The message describing the error or event.
    ///   - error: The associated error object, if any.
    ///   - application: The application context used for storing the error.
    /// - Note: This method is asynchronous and does not throw errors.
    func add(message: String, error: Error?, on application: Application) async
    
    /// Clears out old error items from the database.
    ///
    /// - Parameter database: The database connection to use for deleting expired error records.
    /// - Throws: An error if the database delete operation fails.
    func clear(on database: Database) async throws
}

/// A service for managing errors recorded by the system.
final class ErrorItemsService: ErrorItemsServiceType {
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
