//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Category.
final class Category: Model, @unchecked Sendable {
    static let schema: String = "Categories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "name")
    var name: String

    @Field(key: "nameNormalized")
    var nameNormalized: String
    
    @Children(for: \.$category)
    var hashtags: [CategoryHashtag]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, name: String) {
        self.init()
        
        self.id = id
        self.name = name
        self.nameNormalized = name.uppercased()
    }
}

/// Allows `Category` to be encoded to and decoded from HTTP messages.
extension Category: Content { }
