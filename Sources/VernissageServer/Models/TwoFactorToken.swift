//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Two factor token data.
final class TwoFactorToken: Model, @unchecked Sendable {
    static let schema: String = "TwoFactorTokens"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "userId")
    var user: User
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "backupTokens")
    var backupTokens: [String]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     userId: Int64,
                     key: String,
                     backupTokens: [String]) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.key = key
        self.backupTokens = backupTokens
    }
}

/// Allows `TwoFactorToken` to be encoded to and decoded from HTTP messages.
extension TwoFactorToken: Content { }
