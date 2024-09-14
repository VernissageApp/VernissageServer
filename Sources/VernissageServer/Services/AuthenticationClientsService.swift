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
    func validateUri(on database: Database, uri: String, authClientId: Int64?) async throws
}

/// A website for managing OpenId Connect authorization clients.
final class AuthenticationClientsService: AuthenticationClientsServiceType {
    
    func validateUri(on database: Database, uri: String, authClientId: Int64?) async throws {
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
