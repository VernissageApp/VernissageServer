//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateSettings: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(Setting.schema)
            .id()
            .field("key", .string, .required)
            .field("value", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "key")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Setting.schema).delete()
    }
}
