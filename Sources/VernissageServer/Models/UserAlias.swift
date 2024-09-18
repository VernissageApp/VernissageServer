//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's alias.
final class UserAlias: Model, @unchecked Sendable {
    static let schema: String = "UserAliases"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "alias")
    var alias: String

    @Field(key: "aliasNormalized")
    var aliasNormalized: String
    
    @Field(key: "activityPubProfile")
    var activityPubProfile: String
    
    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = Snowflake.identifier()
    }

    convenience init(id: Int64? = nil, userId: Int64, alias: String, activityPubProfile: String) {
        self.init()

        self.$user.id = userId
        self.alias = alias
        self.aliasNormalized = alias.uppercased()
        self.activityPubProfile = activityPubProfile
    }
}

/// Allows `UserAlias` to be encoded to and decoded from HTTP messages.
extension UserAlias: Content { }
