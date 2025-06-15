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

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "clientSecret")
    var clientSecret: String?
        
    @Timestamp(key: "clientSecretExpiresAt", on: .none)
    var clientSecretExpiresAt: Date?
    
    @Field(key: "redirectUris")
    var redirectUris: String
    
    @Field(key: "tokenEndpointAuthMethod")
    var tokenEndpointAuthMethod: String?
    
    @Field(key: "grantTypes")
    var grantTypes: String
    
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
//    convenience init(from authClientDto: AuthClientDto, withid id: Int64) {
//        self.init(id: id,
//                  type: authClientDto.type,
//                  name: authClientDto.name,
//                  uri: authClientDto.uri,
//                  tenantId: authClientDto.tenantId,
//                  clientId: authClientDto.clientId,
//                  clientSecret: authClientDto.clientSecret,
//                  callbackUrl: authClientDto.callbackUrl,
//                  svgIcon: authClientDto.svgIcon
//        )
//    }
}
