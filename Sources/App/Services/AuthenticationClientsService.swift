//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol AuthenticationClientsServiceType {
    func validateUri(on request: Request, uri: String, authClientId: Int64?) async throws
}

final class AuthenticationClientsService: AuthenticationClientsServiceType {
    
    func validateUri(on request: Request, uri: String, authClientId: Int64?) async throws {
        if let unwrapedAuthClientId = authClientId {
            let authClient = try await  AuthClient.query(on: request.db).group(.and) { verifyUriGroup in
                verifyUriGroup.filter(\.$uri == uri)
                verifyUriGroup.filter(\.$id != unwrapedAuthClientId)
            }.first()

            if authClient != nil {
                throw AuthClientError.authClientWithUriExists
            }
        } else {
            let authClient = try await AuthClient.query(on: request.db).filter(\.$uri == uri).first()
            if authClient != nil {
                throw AuthClientError.authClientWithUriExists
            }
        }
    }
}
