//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Image license.
final class License: Model, @unchecked Sendable {
    static let schema = "Licenses"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "name")
    var name: String

    @Field(key: "code")
    var code: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "url")
    var url: String?
    
    @Children(for: \.$license)
    var attachment: [Attachment]
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }
    
    convenience init(id: Int64? = nil,
                     name: String,
                     code: String,
                     description: String,
                     url: String?
    ) {
        self.init()

        self.name = name
        self.code = code
        self.description = description
        self.url = url
    }
}

/// Allows `License` to be encoded to and decoded from HTTP messages.
extension License: Content { }
