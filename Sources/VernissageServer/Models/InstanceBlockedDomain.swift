//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Domains blocked by instance.
final class InstanceBlockedDomain: Model, @unchecked Sendable {
    static let schema: String = "InstanceBlockedDomains"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "domain")
    var domain: String

    @Field(key: "reason")
    var reason: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }
    
    convenience init(id: Int64, domain: String, reason: String?) {
        self.init()

        self.id = id
        self.domain = domain.lowercased()
        self.reason = reason
    }
}

/// Allows `InstanceBlockedDomain` to be encoded to and decoded from HTTP messages.
extension InstanceBlockedDomain: Content { }
