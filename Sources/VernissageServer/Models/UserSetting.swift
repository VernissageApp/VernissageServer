//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's setting.
final class UserSetting: Model, @unchecked Sendable {
    static let schema = "UserSettings"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "userId")
    var user: User

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     userId: Int64,
                     key: String,
                     value: String
    ) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.key = key
        self.value = value
    }
}

/// Allows `UserSetting` to be encoded to and decoded from HTTP messages.
extension UserSetting: Content { }
