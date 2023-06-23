//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Localizable: Model {
    static let schema: String = "Localizables"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "code")
    var code: String
    
    @Field(key: "locale")
    var locale: String

    @Field(key: "system")
    var system: String

    @Field(key: "user")
    var user: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: Int64? = nil, code: String, locale: String, system: String) {
        self.id = id ?? .init(bitPattern: Frostflake.generate())
        self.code = code
        self.locale = locale
        self.system = system
    }
}

/// Allows `Localizable` to be encoded to and decoded from HTTP messages.
extension Localizable: Content { }
