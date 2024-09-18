//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

enum AuthClientType: String, Codable {
    case apple
    case google
    case microsoft
}

/// OAuth client data.
final class AuthClient: Model, @unchecked Sendable {

    static let schema = "AuthClients"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "type")
    var type: AuthClientType

    @Field(key: "name")
    var name: String

    @Field(key: "uri")
    var uri: String
    
    @Field(key: "tenantId")
    var tenantId: String?

    @Field(key: "clientId")
    var clientId: String

    @Field(key: "clientSecret")
    var clientSecret: String

    @Field(key: "callbackUrl")
    var callbackUrl: String
    
    @Field(key: "svgIcon")
    var svgIcon: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deletedAt", on: .delete)
    var deletedAt: Date?
    
    init() {
        self.id = Snowflake.identifier()
    }
    
    convenience init(id: Int64? = nil,
         type: AuthClientType,
         name: String,
         uri: String,
         tenantId: String?,
         clientId: String,
         clientSecret: String,
         callbackUrl: String,
         svgIcon: String?
    ) {
        self.init()

        self.type = type
        self.name = name
        self.uri = uri
        self.tenantId = tenantId
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
        self.svgIcon = svgIcon
    }
}

extension AuthClient {
    convenience init(from authClientDto: AuthClientDto) {
        self.init(id: authClientDto.id?.toId(),
                  type: authClientDto.type,
                  name: authClientDto.name,
                  uri: authClientDto.uri,
                  tenantId: authClientDto.tenantId,
                  clientId: authClientDto.clientId,
                  clientSecret: authClientDto.clientSecret,
                  callbackUrl: authClientDto.callbackUrl,
                  svgIcon: authClientDto.svgIcon
        )
    }
}
