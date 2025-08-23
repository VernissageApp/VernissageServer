//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct AuthenticationDynamicClientsServiceKey: StorageKey {
        typealias Value = AuthenticationDynamicClientsServiceType
    }

    var authenticationDynamicClientsService: AuthenticationDynamicClientsServiceType {
        get {
            self.application.storage[AuthenticationDynamicClientsServiceKey.self] ?? AuthenticationDynamicClientsService()
        }
        nonmutating set {
            self.application.storage[AuthenticationDynamicClientsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol AuthenticationDynamicClientsServiceType: Sendable {
    /// Retrieves an OAuth dynamic client by its identifier.
    /// - Parameters:
    ///   - id: The identifier of the OAuth client.
    ///   - request: The Vapor request context.
    /// - Returns: The matching `AuthDynamicClient` or nil if not found.
    func get(id: String, on request: Request) async throws -> AuthDynamicClient?
    
    /// Creates a new OAuth dynamic client based on the registration data.
    /// - Parameters:
    ///   - registerOAuthClientRequestDto: Data transfer object containing registration info.
    ///   - userId: The optional user identifier associated with the client.
    ///   - request: The Vapor request context.
    /// - Returns: The created `AuthDynamicClient` instance.
    func create(basedOn registerOAuthClientRequestDto: RegisterOAuthClientRequestDto, for userId: Int64?, on request: Request) async throws -> AuthDynamicClient
}

/// A service for managing OAuth dynamic clients.
final class AuthenticationDynamicClientsService: AuthenticationDynamicClientsServiceType {
    func get(id: String, on request: Request) async throws -> AuthDynamicClient? {
        guard let clientId = Int64(id) else {
            return nil
        }

        return try await AuthDynamicClient.query(on: request.db)
            .filter(\.$id == clientId)
            .first()
    }
    
    func create(basedOn registerOAuthClientRequestDto: RegisterOAuthClientRequestDto, for userId: Int64?, on request: Request) async throws -> AuthDynamicClient {
        let id = request.application.services.snowflakeService.generate()
        
        // Create OAuth client metadata.
        let authDynamicClient = AuthDynamicClient()
        authDynamicClient.id = id
        authDynamicClient.$user.id = userId
        authDynamicClient.redirectUris = registerOAuthClientRequestDto.redirectUris.joined(separator: AuthDynamicClient.separator)
        authDynamicClient.contacts = registerOAuthClientRequestDto.contacts?.joined(separator: AuthDynamicClient.separator)
        authDynamicClient.tokenEndpointAuthMethod = registerOAuthClientRequestDto.tokenEndpointAuthMethod?.rawValue
        authDynamicClient.clientName = registerOAuthClientRequestDto.clientName
        authDynamicClient.clientUri = registerOAuthClientRequestDto.clientUri
        authDynamicClient.logoUri = registerOAuthClientRequestDto.logoUri
        authDynamicClient.scope = registerOAuthClientRequestDto.scope
        authDynamicClient.tosUri = registerOAuthClientRequestDto.tosUri
        authDynamicClient.policyUri = registerOAuthClientRequestDto.policyUri
        authDynamicClient.jwksUri = registerOAuthClientRequestDto.jwksUri
        authDynamicClient.jwks = registerOAuthClientRequestDto.jwks
        authDynamicClient.softwareId = registerOAuthClientRequestDto.softwareId
        authDynamicClient.softwareVersion = registerOAuthClientRequestDto.softwareVersion
        
        // Data from request or "authorization_code".
        if registerOAuthClientRequestDto.grantTypes.count > 0 {
            authDynamicClient.grantTypes = registerOAuthClientRequestDto.grantTypes.map { $0.rawValue }.joined(separator: AuthDynamicClient.separator)
        } else {
            authDynamicClient.grantTypes = OAuthGrantTypeDto.authorizationCode.rawValue
        }
        
        // Data from request or "code".
        if registerOAuthClientRequestDto.responseTypes.count > 0 {
            authDynamicClient.responseTypes = registerOAuthClientRequestDto.responseTypes.map { $0.rawValue }.joined(separator: AuthDynamicClient.separator)
        } else {
            authDynamicClient.responseTypes = OAuthResponseTypeDto.code.rawValue
        }
        
        if registerOAuthClientRequestDto.tokenEndpointAuthMethod == nil || registerOAuthClientRequestDto.tokenEndpointAuthMethod == OAuthTokenEndpointAuthMethodDto.none {
            authDynamicClient.clientSecret = nil
            authDynamicClient.clientSecretExpiresAt = nil
        } else {
            authDynamicClient.clientSecret = String.createRandomString(length: 32)
            authDynamicClient.clientSecretExpiresAt = Date.futureYear
        }
        
        // Save client metadata in the database.
        try await authDynamicClient.save(on: request.db)
        return authDynamicClient
    }
}
