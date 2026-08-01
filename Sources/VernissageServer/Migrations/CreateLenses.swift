//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension Lens {
    struct CreateLenses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Lens.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("name", .string, .required)
                .field("nameNormalized", .string, .required)
                .field("amount", .int, .required, .sql(.default(0)))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "name")
                .unique(on: "nameNormalized")
                .create()

            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            try await sqlDatabase.raw(
                """
                WITH "NormalizedLenses" AS (
                    SELECT
                        "id",
                        TRIM("lens") AS "name",
                        UPPER(TRIM("lens")) AS "nameNormalized"
                    FROM "Exif"
                    WHERE "lens" IS NOT NULL AND TRIM("lens") <> ''
                ),
                "RankedLenses" AS (
                    SELECT
                        "id",
                        "name",
                        "nameNormalized",
                        ROW_NUMBER() OVER (
                            PARTITION BY "nameNormalized"
                            ORDER BY "id"
                        ) AS "position"
                    FROM "NormalizedLenses"
                )
                INSERT INTO "Lenses" ("id", "name", "nameNormalized")
                SELECT "id", "name", "nameNormalized"
                FROM "RankedLenses"
                WHERE "position" = 1
                """
            ).run()
        }

        func revert(on database: Database) async throws {
            try await database.schema(Lens.schema).delete()
        }
    }
}
