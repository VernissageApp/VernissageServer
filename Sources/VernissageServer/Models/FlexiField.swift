//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Field attached to the user.
final class FlexiField: Model, @unchecked Sendable {

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
    
    init() { }
    
    convenience init(id: Int64,
                     key: String?,
                     value: String?,
                     isVerified: Bool,
                     userId: Int64
    ) {
        self.init()

        self.id = id
        self.key = key
        self.value = value
        self.isVerified = isVerified
        self.$user.id = userId
    }
}

extension FlexiField {
    func verifiedAt() -> Date? {
        if self.isVerified == false {
            return nil
        }
        
        return self.updatedAt
    }
    
    func htmlValue(baseAddress: String) -> String {
        guard let value else {
            return ""
        }
        
        return value.html(baseAddress: baseAddress)
    }
}

/// Allows `FlexiField` to be encoded to and decoded from HTTP messages.
extension FlexiField: Content { }
