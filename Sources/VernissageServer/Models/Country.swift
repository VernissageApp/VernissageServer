//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Country data.
final class Country: Model {
    static let schema: String = "Countries"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "name")
    var name: String
        
    @Children(for: \.$country)
    var location: [Location]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil,
                     code: String,
                     name: String) {
        self.init()

        self.code = code
        self.name = name
    }
}

/// Allows `Country` to be encoded to and decoded from HTTP messages.
extension Country: Content { }
