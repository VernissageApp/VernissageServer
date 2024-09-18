//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Instance rule.
final class Rule: Model, @unchecked Sendable {
    static let schema = "Rules"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "order")
    var order: Int
    
    @Field(key: "text")
    var text: String

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() {
        self.id = Snowflake.identifier()
    }
    
    convenience init(id: Int64? = nil,
                     order: Int,
                     text: String
    ) {
        self.init()

        self.order = order
        self.text = text
    }
}

/// Allows `Rule` to be encoded to and decoded from HTTP messages.
extension Rule: Content { }
