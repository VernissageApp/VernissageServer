//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Field attached to the user's business card.
final class BusinessCardField: Model, @unchecked Sendable {
    static let schema = "BusinessCardFields"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "businessCardId")
    var businessCard: BusinessCard
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "value")
    var value: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64,
                     businessCardId: Int64,
                     key: String,
                     value: String
    ) {
        self.init()

        self.id = id
        self.$businessCard.id = businessCardId
        self.key = key
        self.value = value
    }
}

/// Allows `BusinessCardField` to be encoded to and decoded from HTTP messages.
extension BusinessCardField: Content { }
