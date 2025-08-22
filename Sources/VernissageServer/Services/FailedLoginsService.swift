//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct FailedLoginsKey: StorageKey {
        typealias Value = FailedLoginsServiceType
    }

    var failedLoginsService: FailedLoginsServiceType {
        get {
            self.application.storage[FailedLoginsKey.self] ?? FailedLoginsService()
        }
        nonmutating set {
            self.application.storage[FailedLoginsKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol FailedLoginsServiceType: Sendable {
    /// Saves a failed login attempt for a given username and request, recording the associated IP address and timestamp.
    ///
    /// - Parameters:
    ///   - userName: The username for which the failed login attempt should be recorded.
    ///   - request: The HTTP request containing context and database access.
    /// - Throws: An error if saving the failed login record fails.
    func saveFailedLoginAttempt(userName: String, on request: Request) async throws
    
    /// Checks if the maximum number of failed login attempts has been exceeded within a certain time window for a user.
    ///
    /// - Parameters:
    ///   - userName: The username to check failed login attempts for.
    ///   - request: The HTTP request containing context and database access.
    /// - Returns: True if the number of failed attempts exceeds the allowed maximum, false otherwise.
    /// - Throws: An error if the database query fails.
    func loginAttemptsExceeded(userName: String, on request: Request) async throws -> Bool
    
    /// Clears out old failed login records from the database.
    ///
    /// - Parameter database: The database connection to use for deleting expired records.
    /// - Throws: An error if the database delete operation fails.
    func clear(on database: Database) async throws
}

/// A service for managing failed logins in the system.
final class FailedLoginsService: FailedLoginsServiceType {
    private let maximumNumberOfFailedLogins = 5

    public func saveFailedLoginAttempt(userName: String, on request: Request) async throws {
        let id = request.application.services.snowflakeService.generate()
        let failedLogin = FailedLogin(id: id, userName: userName, ip: request.remoteAddress?.ipAddress)
        try await failedLogin.save(on: request.db)
    }
    
    public func loginAttemptsExceeded(userName: String, on request: Request) async throws -> Bool {
        let userNameNormalized = userName.uppercased()
        let fiveMinutesAgo = Date.fiveMinutesAgo

        let attempts = try await FailedLogin.query(on: request.db)
            .filter(\.$userNameNormalized == userNameNormalized)
            .filter(\.$createdAt > fiveMinutesAgo)
            .count()
        
        return attempts >= self.maximumNumberOfFailedLogins
    }
    
    public func clear(on database: Database) async throws {
        let monthAgo = Date.monthAgo

        try await  FailedLogin.query(on: database)
            .filter(\.$createdAt < monthAgo)
            .delete()
    }
}
