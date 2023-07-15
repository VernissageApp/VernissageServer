//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class FlexiField: Model {

    static let schema = "FlexiFields"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "key")
    var key: String?
    
    @Field(key: "value")
    var value: String?
    
    @Field(key: "isVerified")
    var isVerified: Bool
    
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
         key: String?,
         value: String?,
         isVerified: Bool,
         userId: Int64
    ) {
        self.init()

        self.key = key
        self.value = value
        self.isVerified = isVerified
        self.$user.id = userId
    }
}

/// Allows `FlexiField` to be encoded to and decoded from HTTP messages.
extension FlexiField: Content { }
