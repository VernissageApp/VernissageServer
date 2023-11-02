//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Rule: Model {
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
        self.id = .init(bitPattern: Frostflake.generate())
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
