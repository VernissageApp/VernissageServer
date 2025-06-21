//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {

    func createAuthDynamicClient(clientName: String? = nil,
                                 clientUri: String? = nil,
                                 redirectUris: [String],
                                 tokenEndpointAuthMethod: OAuthTokenEndpointAuthMethodDto = .none,
                                 scope: String = "read write profile",
                                 grantTypes: [OAuthGrantTypeDto],
                                 responseTypes: [OAuthResponseTypeDto],
                                 userId: Int64? = nil) async throws -> AuthDynamicClient {
        let id =  await ApplicationManager.shared.generateId()
        
        // Create OAuth client metadata.
        let authDynamicClient = AuthDynamicClient()
        authDynamicClient.id = id
        authDynamicClient.$user.id = userId

        authDynamicClient.clientName = clientName
        authDynamicClient.clientUri = clientUri
        authDynamicClient.redirectUris = redirectUris.joined(separator: ",")
        authDynamicClient.tokenEndpointAuthMethod = tokenEndpointAuthMethod.rawValue

        authDynamicClient.logoUri = ""
        authDynamicClient.scope = scope
        authDynamicClient.contacts = ""
        authDynamicClient.tosUri = nil
        authDynamicClient.policyUri = nil
        authDynamicClient.jwksUri = nil
        authDynamicClient.jwks = nil
        authDynamicClient.softwareId = nil
        authDynamicClient.softwareVersion = nil
        
        authDynamicClient.grantTypes = grantTypes.map({ $0.rawValue }).joined(separator: ",")
        authDynamicClient.responseTypes = responseTypes.map({ $0.rawValue }).joined(separator: ",")
        
        if tokenEndpointAuthMethod != .none {
            authDynamicClient.clientSecret = String.createRandomString(length: 32)
            authDynamicClient.clientSecretExpiresAt = Date.futureYear
        }
        
        // Save client metadata in the database.
        try await authDynamicClient.save(on: self.db)
        return authDynamicClient
    }

    func getAuthDynamicClient(id: Int64) async throws -> AuthDynamicClient {
        guard let authClient = try await AuthDynamicClient.query(on: self.db).filter(\.$id == id).first() else {
            throw SharedApplicationError.unwrap
        }

        return authClient
    }
}
