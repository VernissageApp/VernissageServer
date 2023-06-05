//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

final class BlockedDomain: Model {
    static let schema: String = "BlockedDomains"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "domain")
    var domain: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {}

    init(domain: String) {
        self.domain = domain
    }
}

/// Allows `BlockedDomain` to be encoded to and decoded from HTTP messages.
extension BlockedDomain: Content { }
