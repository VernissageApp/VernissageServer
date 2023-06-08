//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class UserBlockedDomain: Model {
    static let schema: String = "UserBlockedDomains"

    @ID(custom: .id, generatedBy: .user)
    var id: UInt64?

    @Field(key: "domain")
    var domain: String

    @Field(key: "reason")
    var reason: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UInt64?, domain: String, reason: String?) {
        self.id = id ?? Frostflake.generate()
        self.domain = domain
        self.reason = reason
    }
}

/// Allows `UserBlockedDomain` to be encoded to and decoded from HTTP messages.
extension UserBlockedDomain: Content { }
