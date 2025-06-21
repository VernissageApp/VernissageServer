//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

/// OAuth dynamic client metadata.
final class AuthDynamicClient: Model, @unchecked Sendable {

    static let schema = "AuthDynamicClients"
    static let separator = ","

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @OptionalParent(key: "userId")
    var user: User?

    @Field(key: "clientSecret")
    var clientSecret: String?
        
    @Timestamp(key: "clientSecretExpiresAt", on: .none)
    var clientSecretExpiresAt: Date?
    
    /// Comma separated URLs.
    @Field(key: "redirectUris")
    var redirectUris: String
    
    @Field(key: "tokenEndpointAuthMethod")
    var tokenEndpointAuthMethod: String?
    
    /// Comma separated grant types.
    @Field(key: "grantTypes")
    var grantTypes: String
    
    /// Comma separated response types.
    @Field(key: "responseTypes")
    var responseTypes: String
    
    @Field(key: "clientName")
    var clientName: String?
    
    @Field(key: "clientUri")
    var clientUri: String?
    
    @Field(key: "logoUri")
    var logoUri: String?
    
    @Field(key: "scope")
    var scope: String?
    
    /// Comma separated email addresses.
    @Field(key: "contacts")
    var contacts: String?
    
    @Field(key: "tosUri")
    var tosUri: String?
    
    @Field(key: "policyUri")
    var policyUri: String?
    
    @Field(key: "jwksUri")
    var jwksUri: String?
    
    @Field(key: "jwks")
    var jwks: String?
    
    @Field(key: "softwareId")
    var softwareId: String?
    
    @Field(key: "softwareVersion")
    var softwareVersion: String?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
}

extension AuthDynamicClient {
    var redirectUrisArray: [String] {
        return self.redirectUris.components(separatedBy: AuthDynamicClient.separator)
    }
    
    var grantTypesArray: [String] {
        return self.grantTypes.components(separatedBy: AuthDynamicClient.separator)
    }
    
    var contactsArray: [String]? {
        return self.contacts?.components(separatedBy: AuthDynamicClient.separator)
    }
    
    var responseTypesArray: [String] {
        return self.responseTypes.components(separatedBy: AuthDynamicClient.separator)
    }
    
    var scopesArray: [String]? {
        return self.scope?.components(separatedBy: " ")
    }
}
