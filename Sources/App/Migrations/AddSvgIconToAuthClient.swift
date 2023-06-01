//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct AddSvgIconToAuthClient: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database
            .schema(AuthClient.schema)
            .field("svgIcon", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(AuthClient.schema).deleteField("svgIcon").update()
    }
}
