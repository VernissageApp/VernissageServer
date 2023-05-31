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
    func validateUri(on request: Request, uri: String, authClientId: UUID?) async throws
}

final class AuthenticationClientsService: AuthenticationClientsServiceType {
    
    func validateUri(on request: Request, uri: String, authClientId: UUID?) async throws {
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
