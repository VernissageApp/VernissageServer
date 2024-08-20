//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

/// Information about disposabled domains. That kind of domains cannot be used during registration process.
final class DisposableEmail: Model, @unchecked Sendable {
    static let schema: String = "DisposableEmails"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "domain")
    var domain: String

    @Field(key: "domainNormalized")
    var domainNormalized: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, domain: String) {
        self.init()

        self.domain = domain
        self.domainNormalized = domain.uppercased()
    }
}

/// Allows `DisposableEmail` to be encoded to and decoded from HTTP messages.
extension DisposableEmail: Content { }
