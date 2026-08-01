//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension LensStatus {
    struct CreateLensStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(LensStatus.schema)
                .field(
                    "lensId",
                    .int64,
                    .required,
                    .references(Lens.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .field(
                    "statusId",
                    .int64,
                    .required,
                    .references(Status.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .compositeIdentifier(over: "lensId", "statusId")
                .create()

            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            try await sqlDatabase
                .create(index: "\(LensStatus.schema)_statusIdIndex")
                .on(LensStatus.schema)
                .column("statusId")
                .run()

            try await sqlDatabase.raw(
                """
                INSERT INTO "LensStatuses" ("lensId", "statusId")
                SELECT DISTINCT "Lenses"."id", "Attachments"."statusId"
                FROM "Exif"
                INNER JOIN "Attachments"
                    ON "Attachments"."id" = "Exif"."attachmentId"
                INNER JOIN "Lenses"
                    ON "Lenses"."nameNormalized" = UPPER(TRIM("Exif"."lens"))
                WHERE "Attachments"."statusId" IS NOT NULL
                    AND "Exif"."lens" IS NOT NULL
                    AND TRIM("Exif"."lens") <> ''
                """
            ).run()

            try await sqlDatabase.raw(
                """
                UPDATE "Lenses"
                SET "amount" = (
                    SELECT COUNT(*)
                    FROM "Exif"
                    INNER JOIN "Attachments"
                        ON "Attachments"."id" = "Exif"."attachmentId"
                    INNER JOIN "Statuses"
                        ON "Statuses"."id" = "Attachments"."statusId"
                    WHERE UPPER(TRIM("Exif"."lens")) = "Lenses"."nameNormalized"
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
                    UPDATE "Lenses"
                    SET "amount" = 0
                    """
                ).run()
            }

            try await database.schema(LensStatus.schema).delete()
        }
    }
}
