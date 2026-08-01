//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension Film {
    struct CreateFilms: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Film.schema)
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
                WITH "NormalizedFilms" AS (
                    SELECT
                        "id",
                        TRIM("film") AS "name",
                        UPPER(TRIM("film")) AS "nameNormalized"
                    FROM "Exif"
                    WHERE "film" IS NOT NULL AND TRIM("film") <> ''
                ),
                "RankedFilms" AS (
                    SELECT
                        "id",
                        "name",
                        "nameNormalized",
                        ROW_NUMBER() OVER (
                            PARTITION BY "nameNormalized"
                            ORDER BY "id"
                        ) AS "position"
                    FROM "NormalizedFilms"
                )
                INSERT INTO "Films" ("id", "name", "nameNormalized")
                SELECT "id", "name", "nameNormalized"
                FROM "RankedFilms"
                WHERE "position" = 1
                """
            ).run()
        }

        func revert(on database: Database) async throws {
            try await database.schema(Film.schema).delete()
        }
    }
}
