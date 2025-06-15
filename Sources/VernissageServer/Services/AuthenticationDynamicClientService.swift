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
    func create(on: Request, registerOAuthClientRequestDto: RegisterOAuthClientRequestDto) async throws -> AuthDynamicClient
}

/// A service for managing OAuth dynamic clients.
final class AuthenticationDynamicClientsService: AuthenticationDynamicClientsServiceType {
    func create(on request: Request, registerOAuthClientRequestDto: RegisterOAuthClientRequestDto) async throws -> AuthDynamicClient {
        let id = request.application.services.snowflakeService.generate()
        
        // Create OAuth client metadata.
        let authDynamicClient = AuthDynamicClient()
        authDynamicClient.id = id
        authDynamicClient.redirectUris = registerOAuthClientRequestDto.redirectUris.joined(separator: ",")
        authDynamicClient.tokenEndpointAuthMethod = registerOAuthClientRequestDto.tokenEndpointAuthMethod?.rawValue
        
        
        authDynamicClient.clientName = registerOAuthClientRequestDto.clientName
        authDynamicClient.clientUri = registerOAuthClientRequestDto.clientUri
        authDynamicClient.logoUri = registerOAuthClientRequestDto.logoUri
        authDynamicClient.scope = registerOAuthClientRequestDto.scope
        authDynamicClient.contacts = registerOAuthClientRequestDto.contacts?.joined(separator: ",")
        authDynamicClient.tosUri = registerOAuthClientRequestDto.tosUri
        authDynamicClient.policyUri = registerOAuthClientRequestDto.policyUri
        authDynamicClient.jwksUri = registerOAuthClientRequestDto.jwksUri
        authDynamicClient.jwks = registerOAuthClientRequestDto.jwks
        authDynamicClient.softwareId = registerOAuthClientRequestDto.softwareId
        authDynamicClient.softwareVersion = registerOAuthClientRequestDto.softwareVersion
        
        // Data from request or "authorization_code".
        let grantTypes = registerOAuthClientRequestDto.grantTypes.map { $0.rawValue }.joined(separator: ",")
        if grantTypes.count > 0 {
            authDynamicClient.grantTypes = grantTypes
        } else {
            authDynamicClient.grantTypes = OAuthGrantTypeDto.authorizationCode.rawValue
        }
        
        // Data from request or "code".
        let responseTypes = registerOAuthClientRequestDto.responseTypes.map { $0.rawValue }.joined(separator: ",")
        if responseTypes.count > 0 {
            authDynamicClient.responseTypes = responseTypes
        } else {
            authDynamicClient.responseTypes = OAuthResponseTypeDto.code.rawValue
        }
        
        if registerOAuthClientRequestDto.tokenEndpointAuthMethod == nil || registerOAuthClientRequestDto.tokenEndpointAuthMethod == OAuthTokenEndpointAuthMethodDto.none {
            authDynamicClient.clientSecret = nil
            authDynamicClient.clientSecretExpiresAt = nil
        } else {
            authDynamicClient.clientSecret = String.createRandomString(length: 36)
            authDynamicClient.clientSecretExpiresAt = Date.futureYear
        }
        
        // Save client metadata in the database.
        try await authDynamicClient.save(on: request.db)
        return authDynamicClient
    }
}
