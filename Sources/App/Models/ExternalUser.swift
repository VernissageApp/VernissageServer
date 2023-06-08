//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class ExternalUser: Model {
    static let schema = "ExternalUsers"
    
    @ID(custom: .id, generatedBy: .user)
    var id: UInt64?
    
    @Field(key: "type")
    var type: AuthClientType
    
    @Field(key: "externalId")
    var externalId: String
    
    @Field(key: "authenticationToken")
    var authenticationToken: String?
    
    @Field(key: "tokenCreatedAt")
    var tokenCreatedAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UInt64? = nil,
         type: AuthClientType,
         externalId: String,
         userId: UInt64
    ) {
        self.id = id ?? Frostflake.generate()
        self.type = type
        self.externalId = externalId
        self.$user.id = userId
    }
}

/// Allows `ExternalUser` to be encoded to and decoded from HTTP messages.
extension ExternalUser: Content { }
