//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Category: Model {
    static let schema: String = "Categories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "name")
    var name: String
    
    @Children(for: \.$category)
    var hashtags: [CategoryHashtag]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, name: String) {
        self.init()
        self.name = name
    }
}

/// Allows `Category` to be encoded to and decoded from HTTP messages.
extension Category: Content { }