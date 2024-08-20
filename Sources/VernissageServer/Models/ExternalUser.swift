//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Information about external user created from OAuth.
final class ExternalUser: Model, @unchecked Sendable {
    static let schema = "ExternalUsers"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
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
    
    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }
    
    convenience init(id: Int64? = nil,
         type: AuthClientType,
         externalId: String,
         userId: Int64
    ) {
        self.init()

        self.type = type
        self.externalId = externalId
        self.$user.id = userId
    }
}

/// Allows `ExternalUser` to be encoded to and decoded from HTTP messages.
extension ExternalUser: Content { }
