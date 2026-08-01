//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension Camera {
    struct CreateCameras: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Camera.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("name", .string, .required)
                .field("nameNormalized", .string, .required)
                .field("make", .string)
                .field("model", .string)
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
                WITH "NormalizedExif" AS (
                    SELECT
                        "id",
                        NULLIF(TRIM("make"), '') AS "make",
                        NULLIF(TRIM("model"), '') AS "model"
                    FROM "Exif"
                ),
                "NamedCameras" AS (
                    SELECT
                        "id",
                        "make",
                        "model",
                        CASE
                            WHEN "make" IS NULL THEN "model"
                            WHEN "model" IS NULL THEN "make"
                            WHEN LOWER(SUBSTR("model", 1, LENGTH("make"))) = LOWER("make")
                                THEN TRIM("make" || ' ' || TRIM(SUBSTR("model", LENGTH("make") + 1)))
                            ELSE "make" || ' ' || "model"
                        END AS "name"
                    FROM "NormalizedExif"
                    WHERE "make" IS NOT NULL OR "model" IS NOT NULL
                ),
                "NormalizedCameraNames" AS (
                    SELECT
                        "id",
                        "name",
                        UPPER("name") AS "nameNormalized",
                        "make",
                        "model"
                    FROM "NamedCameras"
                    WHERE "name" IS NOT NULL AND "name" <> ''
                ),
                "RankedCameras" AS (
                    SELECT
                        "id",
                        "name",
                        "nameNormalized",
                        "make",
                        "model",
                        ROW_NUMBER() OVER (
                            PARTITION BY "nameNormalized"
                            ORDER BY "id"
                        ) AS "position"
                    FROM "NormalizedCameraNames"
                )
                INSERT INTO "Cameras" ("id", "name", "nameNormalized", "make", "model")
                SELECT "id", "name", "nameNormalized", "make", "model"
                FROM "RankedCameras"
                WHERE "position" = 1
                """
            ).run()
        }

        func revert(on database: Database) async throws {
            try await database.schema(Camera.schema).delete()
        }
    }
}
