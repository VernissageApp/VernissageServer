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
    func saveFailedLoginAttempt(userName: String, on request: Request) async throws
    func loginAttempsExceeded(userName: String, on request: Request) async throws -> Bool
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
    
    public func loginAttempsExceeded(userName: String, on request: Request) async throws -> Bool {
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
