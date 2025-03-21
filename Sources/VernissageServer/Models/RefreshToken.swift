//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User refresh token.
final class RefreshToken: Model, @unchecked Sendable {

    static let schema = "RefreshTokens"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "expiryDate")
    var expiryDate: Date
    
    @Field(key: "revoked")
    var revoked: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Parent(key: "userId")
    var user: User
    
    init() { }
    
    convenience init(id: Int64,
         userId: Int64,
         token: String,
         expiryDate: Date,
         revoked: Bool = false
    ) {
        self.init()

        self.id = id
        self.token = token
        self.expiryDate = expiryDate
        self.revoked = revoked
        self.$user.id = userId
    }
}

/// Allows `RefreshToken` to be encoded to and decoded from HTTP messages.
extension RefreshToken: Content { }
