//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Strings localizables.
final class Localizable: Model, @unchecked Sendable {
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

    init() {
        self.id = Snowflake.identifier()
    }

    convenience init(id: Int64? = nil, code: String, locale: String, system: String) {
        self.init()

        self.code = code
        self.locale = locale
        self.system = system
    }
}

/// Allows `Localizable` to be encoded to and decoded from HTTP messages.
extension Localizable: Content { }
