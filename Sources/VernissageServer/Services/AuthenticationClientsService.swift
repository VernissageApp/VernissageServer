//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct AuthenticationClientsServiceKey: StorageKey {
        typealias Value = AuthenticationClientsServiceType
    }

    var authenticationClientsService: AuthenticationClientsServiceType {
        get {
            self.application.storage[AuthenticationClientsServiceKey.self] ?? AuthenticationClientsService()
        }
        nonmutating set {
            self.application.storage[AuthenticationClientsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol AuthenticationClientsServiceType: Sendable {
    /// Validates the uniqueness of an OpenID Connect authorization client URI.
    /// - Parameters:
    ///   - uri: The URI to validate for uniqueness.
    ///   - authClientId: Optional client identifier (used when updating an existing client).
    ///   - database: The database context.
    /// - Throws: `AuthClientError.authClientWithUriExists` if a client with the same URI already exists.
    func validate(uri: String, authClientId: Int64?, on database: Database) async throws
}

/// A website for managing OpenId Connect authorization clients.
final class AuthenticationClientsService: AuthenticationClientsServiceType {
    
    func validate(uri: String, authClientId: Int64?, on database: Database) async throws {
        if let unwrapedAuthClientId = authClientId {
            let authClient = try await  AuthClient.query(on: database).group(.and) { verifyUriGroup in
                verifyUriGroup.filter(\.$uri == uri)
                verifyUriGroup.filter(\.$id != unwrapedAuthClientId)
            }.first()

            if authClient != nil {
                throw AuthClientError.authClientWithUriExists
            }
        } else {
            let authClient = try await AuthClient.query(on: database).filter(\.$uri == uri).first()
            if authClient != nil {
                throw AuthClientError.authClientWithUriExists
            }
        }
    }
}
