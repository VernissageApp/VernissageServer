//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension FilmStatus {
    struct CreateFilmStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FilmStatus.schema)
                .field(
                    "filmId",
                    .int64,
                    .required,
                    .references(Film.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .field(
                    "statusId",
                    .int64,
                    .required,
                    .references(Status.schema, "id", onDelete: .cascade, onUpdate: .cascade)
                )
                .compositeIdentifier(over: "filmId", "statusId")
                .create()

            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            try await sqlDatabase
                .create(index: "\(FilmStatus.schema)_statusIdIndex")
                .on(FilmStatus.schema)
                .column("statusId")
                .run()

            try await sqlDatabase.raw(
                """
                INSERT INTO "FilmStatuses" ("filmId", "statusId")
                SELECT DISTINCT "Films"."id", "Attachments"."statusId"
                FROM "Exif"
                INNER JOIN "Attachments"
                    ON "Attachments"."id" = "Exif"."attachmentId"
                INNER JOIN "Films"
                    ON "Films"."nameNormalized" = UPPER(TRIM("Exif"."film"))
                WHERE "Attachments"."statusId" IS NOT NULL
                    AND "Exif"."film" IS NOT NULL
                    AND TRIM("Exif"."film") <> ''
                """
            ).run()

            try await sqlDatabase.raw(
                """
                UPDATE "Films"
                SET "amount" = (
                    SELECT COUNT(*)
                    FROM "Exif"
                    INNER JOIN "Attachments"
                        ON "Attachments"."id" = "Exif"."attachmentId"
                    INNER JOIN "Statuses"
                        ON "Statuses"."id" = "Attachments"."statusId"
                    WHERE UPPER(TRIM("Exif"."film")) = "Films"."nameNormalized"
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
                    UPDATE "Films"
                    SET "amount" = 0
                    """
                ).run()
            }

            try await database.schema(FilmStatus.schema).delete()
        }
    }
}
