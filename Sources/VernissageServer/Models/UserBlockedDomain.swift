//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Domain blocked by the user.
final class UserBlockedDomain: Model {
    static let schema: String = "UserBlockedDomains"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "domain")
    var domain: String

    @Field(key: "reason")
    var reason: String?
    
    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, userId: Int64, domain: String, reason: String?) {
        self.init()

        self.$user.id = userId
        self.domain = domain.lowercased()
        self.reason = reason
    }
}

/// Allows `UserBlockedDomain` to be encoded to and decoded from HTTP messages.
extension UserBlockedDomain: Content { }
