//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension CameraStatus {
    struct CreateCameraStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(CameraStatus.schema)
                .field(
                    "cameraId",
                    .int64,
                    .required,
                    .references(Camera.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .field(
                    "statusId",
                    .int64,
                    .required,
                    .references(Status.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .compositeIdentifier(over: "cameraId", "statusId")
                .create()

            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            try await sqlDatabase
                .create(index: "\(CameraStatus.schema)_statusIdIndex")
                .on(CameraStatus.schema)
                .column("statusId")
                .run()

            try await sqlDatabase.raw(
                """
                WITH "NormalizedExif" AS (
                    SELECT
                        "attachmentId",
                        NULLIF(TRIM("make"), '') AS "make",
                        NULLIF(TRIM("model"), '') AS "model"
                    FROM "Exif"
                ),
                "NamedCameraExif" AS (
                    SELECT
                        "attachmentId",
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
                        "attachmentId",
                        UPPER("name") AS "nameNormalized"
                    FROM "NamedCameraExif"
                    WHERE "name" IS NOT NULL AND "name" <> ''
                )
                INSERT INTO "CameraStatuses" ("cameraId", "statusId")
                SELECT DISTINCT "Cameras"."id", "Attachments"."statusId"
                FROM "NormalizedCameraNames"
                INNER JOIN "Attachments"
                    ON "Attachments"."id" = "NormalizedCameraNames"."attachmentId"
                INNER JOIN "Cameras"
                    ON "Cameras"."nameNormalized" = "NormalizedCameraNames"."nameNormalized"
                WHERE "Attachments"."statusId" IS NOT NULL
                """
            ).run()

            try await sqlDatabase.raw(
                """
                WITH "NormalizedExif" AS (
                    SELECT
                        "attachmentId",
                        NULLIF(TRIM("make"), '') AS "make",
                        NULLIF(TRIM("model"), '') AS "model"
                    FROM "Exif"
                ),
                "NamedCameraExif" AS (
                    SELECT
                        "attachmentId",
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
                        "attachmentId",
                        UPPER("name") AS "nameNormalized"
                    FROM "NamedCameraExif"
                    WHERE "name" IS NOT NULL AND "name" <> ''
                )
                UPDATE "Cameras"
                SET "amount" = (
                    SELECT COUNT(*)
                    FROM "NormalizedCameraNames"
                    INNER JOIN "Attachments"
                        ON "Attachments"."id" = "NormalizedCameraNames"."attachmentId"
                    INNER JOIN "Statuses"
                        ON "Statuses"."id" = "Attachments"."statusId"
                    WHERE "NormalizedCameraNames"."nameNormalized" = "Cameras"."nameNormalized"
                        AND "Attachments"."statusId" IS NOT NULL
                        AND "Statuses"."visibility" IN (
                            \(bind: StatusVisibility.public.rawValue),
                            \(bind: StatusVisibility.quietPublic.rawValue)
                        )
                )
                """
            ).run()
        }

        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase.raw(
                    """
                    UPDATE "Cameras"
                    SET "amount" = 0
                    """
                ).run()
            }

            try await database.schema(CameraStatus.schema).delete()
        }
    }
}
