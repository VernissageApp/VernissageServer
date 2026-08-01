//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension Application.Services {
    struct ExifServiceKey: StorageKey {
        typealias Value = ExifServiceType
    }

    var exifService: ExifServiceType {
        get {
            self.application.storage[ExifServiceKey.self] ?? ExifService()
        }
        nonmutating set {
            self.application.storage[ExifServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ExifServiceType: Sendable {
    /// Synchronizes camera, lens and film dictionaries and their status relationships.
    ///
    /// The provided context should use the transaction in which attachment-to-status
    /// relationships have already been updated.
    func synchronize(
        statusId: Int64,
        previousAttachments: [Attachment],
        attachments: [Attachment],
        previousVisibility: StatusVisibility?,
        visibility: StatusVisibility?,
        on context: ExecutionContext
    ) async throws

    /// Synchronizes camera, lens and film metadata after changing EXIF on an
    /// attachment that is already assigned to a status.
    func synchronize(
        statusId: Int64,
        attachmentId: Int64,
        previousExif: ExifTimelineMetadata?,
        visibility: StatusVisibility,
        on context: ExecutionContext
    ) async throws
}

/// A service for synchronizing EXIF dictionaries and their status relationships.
final class ExifService: ExifServiceType {
    private struct CameraMetadata {
        let name: String
        let nameNormalized: String
        let make: String?
        let model: String?
    }

    private struct NameMetadata {
        let name: String
        let nameNormalized: String
    }

    func synchronize(
        statusId: Int64,
        previousAttachments: [Attachment],
        attachments: [Attachment],
        previousVisibility: StatusVisibility?,
        visibility: StatusVisibility?,
        on context: ExecutionContext
    ) async throws {
        // This service uses bulk inserts and atomic counter updates, so it requires
        // access to the SQLKit database that backs the current transaction.
        guard let sqlDatabase = context.db as? SQLDatabase else {
            throw ExifServiceError.sqlDatabaseRequired
        }

        // Build a unique set of all attachments involved in the change. The same
        // attachment can be present in both collections when it remains on the status.
        let previousAttachmentIds = Self.unique(try previousAttachments.map { try $0.requireID() })
        let attachmentIds = Self.unique(try attachments.map { try $0.requireID() })
        let allAttachmentIds = Self.unique(previousAttachmentIds + attachmentIds)

        // Load EXIF rows for both the previous and current state in one query.
        let exifItems: [Exif]
        if allAttachmentIds.isEmpty {
            exifItems = []
        } else {
            exifItems = try await Exif.query(on: context.db)
                .filter(\.$attachment.$id ~~ allAttachmentIds)
                .all()
        }

        // Split the fetched rows back into immutable snapshots representing the
        // status before and after its attachments were changed.
        let exifByAttachmentId = Dictionary(grouping: exifItems, by: \.$attachment.id)
        let previousExifItems = previousAttachmentIds
            .flatMap { exifByAttachmentId[$0] ?? [] }
            .map(ExifTimelineMetadata.init)

        let currentExifItems = attachmentIds
            .flatMap { exifByAttachmentId[$0] ?? [] }
            .map(ExifTimelineMetadata.init)

        // Delegate dictionary, relationship and counter synchronization to the
        // common implementation using the complete current state for relationships.
        try await self.synchronize(
            statusId: statusId,
            previousExifItems: previousExifItems,
            currentExifItems: currentExifItems,
            relationshipExifItems: currentExifItems,
            previousVisibility: previousVisibility,
            visibility: visibility,
            on: context,
            sqlDatabase: sqlDatabase
        )
    }

    func synchronize(
        statusId: Int64,
        attachmentId: Int64,
        previousExif: ExifTimelineMetadata?,
        visibility: StatusVisibility,
        on context: ExecutionContext
    ) async throws {
        // This path is used after an EXIF row is changed in place and must execute
        // inside the same SQL transaction as the attachment update.
        guard let sqlDatabase = context.db as? SQLDatabase else {
            throw ExifServiceError.sqlDatabaseRequired
        }

        // Reload every attachment assigned to the status because its relationships
        // must represent the complete current EXIF state, not only the edited photo.
        let attachments = try await Attachment.query(on: context.db)
            .filter(\.$status.$id == statusId)
            .with(\.$exif)
            .all()

        // Build the desired relationship state from all current EXIF rows.
        let currentExifItems = attachments
            .compactMap(\.exif)
            .map(ExifTimelineMetadata.init)

        // Isolate the new value of the edited attachment. Together with previousExif
        // it provides the exact counter difference introduced by this single update.
        let updatedExif = attachments
            .first { $0.id == attachmentId }?
            .exif
            .map(ExifTimelineMetadata.init)

        // Rebuild relationships from all attachments, but update amounts only by
        // comparing the old and new EXIF value of the edited attachment.
        try await self.synchronize(
            statusId: statusId,
            previousExifItems: previousExif.map { [$0] } ?? [],
            currentExifItems: updatedExif.map { [$0] } ?? [],
            relationshipExifItems: currentExifItems,
            previousVisibility: visibility,
            visibility: visibility,
            on: context,
            sqlDatabase: sqlDatabase
        )
    }

    private func synchronize(
        statusId: Int64,
        previousExifItems: [ExifTimelineMetadata],
        currentExifItems: [ExifTimelineMetadata],
        relationshipExifItems: [ExifTimelineMetadata],
        previousVisibility: StatusVisibility?,
        visibility: StatusVisibility?,
        on context: ExecutionContext,
        sqlDatabase: SQLDatabase
    ) async throws {
        // Only public and quiet-public photos contribute to the counters. Keeping
        // separate previous/current maps also handles visibility changes correctly.
        let previousCameraAmounts = Self.contributesToAmount(previousVisibility) ? Self.cameraAmounts(from: previousExifItems) : [:]
        let cameraAmounts = Self.contributesToAmount(visibility) ? Self.cameraAmounts(from: currentExifItems) : [:]
        let previousLensAmounts = Self.contributesToAmount(previousVisibility) ? Self.lensAmounts(from: previousExifItems) : [:]
        let lensAmounts = Self.contributesToAmount(visibility) ? Self.lensAmounts(from: currentExifItems) : [:]
        let previousFilmAmounts = Self.contributesToAmount(previousVisibility) ? Self.filmAmounts(from: previousExifItems) : [:]
        let filmAmounts = Self.contributesToAmount(visibility) ? Self.filmAmounts(from: currentExifItems) : [:]

        // Collect metadata from both removed and desired values. Removed values are
        // needed to resolve dictionary rows whose counters must be decremented.
        var cameraMetadataByNormalizedName: [String: CameraMetadata] = [:]
        for exif in previousExifItems + relationshipExifItems {
            guard let camera = Self.cameraMetadata(make: exif.make, model: exif.model),
                  cameraMetadataByNormalizedName[camera.nameNormalized] == nil else {
                continue
            }

            cameraMetadataByNormalizedName[camera.nameNormalized] = camera
        }

        let lensMetadata = Self.nameMetadata(from: (previousExifItems + relationshipExifItems).map(\.lens))
        let filmMetadata = Self.nameMetadata(from: (previousExifItems + relationshipExifItems).map(\.film))

        // Make sure every normalized EXIF value has a dictionary row before creating
        // relationships or applying counter differences.
        let cameras = try await self.ensureCameras(Array(cameraMetadataByNormalizedName.values), on: context, sqlDatabase: sqlDatabase)
        let lenses = try await self.ensureLenses(Array(lensMetadata.values), on: context, sqlDatabase: sqlDatabase)
        let films = try await self.ensureFilms(Array(filmMetadata.values), on: context, sqlDatabase: sqlDatabase)

        // Rebuild the status relationships from the desired state. This keeps pivots
        // correct when metadata is removed, replaced or shared by several photos.
        try await CameraStatus.query(on: context.db)
            .filter(\.$id.$status.$id == statusId)
            .delete()

        try await LensStatus.query(on: context.db)
            .filter(\.$id.$status.$id == statusId)
            .delete()

        try await FilmStatus.query(on: context.db)
            .filter(\.$id.$status.$id == statusId)
            .delete()

        // Index dictionary rows by normalized name so relationship creation and
        // counter updates can resolve database identifiers without more queries.
        let camerasByNormalizedName = Dictionary(uniqueKeysWithValues: cameras.map { ($0.nameNormalized, $0) })
        let lensesByNormalizedName = Dictionary(uniqueKeysWithValues: lenses.map { ($0.nameNormalized, $0) })
        let filmsByNormalizedName = Dictionary(uniqueKeysWithValues: films.map { ($0.nameNormalized, $0) })

        // Create one relationship per distinct camera, lens and film used by the
        // status, regardless of how many attachments contain the same value.
        try await self.createCameraStatuses(
            statusId: statusId,
            normalizedNames: Set(Self.cameraAmounts(from: relationshipExifItems).keys),
            camerasByNormalizedName: camerasByNormalizedName,
            on: sqlDatabase
        )

        try await self.createLensStatuses(
            statusId: statusId,
            normalizedNames: Set(Self.lensAmounts(from: relationshipExifItems).keys),
            lensesByNormalizedName: lensesByNormalizedName,
            on: sqlDatabase
        )

        try await self.createFilmStatuses(
            statusId: statusId,
            normalizedNames: Set(Self.filmAmounts(from: relationshipExifItems).keys),
            filmsByNormalizedName: filmsByNormalizedName,
            on: sqlDatabase
        )

        // Apply only the difference between the previous and current number of
        // eligible photos, leaving unrelated dictionary counters untouched.
        try await self.updateCameraAmounts(
            previous: previousCameraAmounts,
            current: cameraAmounts,
            camerasByNormalizedName: camerasByNormalizedName,
            on: sqlDatabase
        )

        try await self.updateLensAmounts(
            previous: previousLensAmounts,
            current: lensAmounts,
            lensesByNormalizedName: lensesByNormalizedName,
            on: sqlDatabase
        )

        try await self.updateFilmAmounts(
            previous: previousFilmAmounts,
            current: filmAmounts,
            filmsByNormalizedName: filmsByNormalizedName,
            on: sqlDatabase
        )
    }

    static func cameraName(make: String?, model: String?) -> String? {
        // Use the same camera naming rules everywhere, including migrations and
        // runtime synchronization.
        self.cameraMetadata(make: make, model: model)?.name
    }

    static func nameNormalized(_ value: String?) -> String? {
        // Dictionary lookups are case-insensitive and ignore surrounding spaces.
        self.normalized(value)?.uppercased()
    }

    private static func cameraMetadata(make: String?, model: String?) -> CameraMetadata? {
        // Clean both EXIF fields before deciding how the display and lookup names
        // should be assembled.
        let normalizedMake = self.normalized(make)
        let normalizedModel = self.normalized(model)

        // Preserve useful partial metadata when only make or model is available.
        switch (normalizedMake, normalizedModel) {
        case (nil, nil):
            return nil
        case (let make?, nil):
            return CameraMetadata(name: make, nameNormalized: make.uppercased(), make: make, model: nil)
        case (nil, let model?):
            return CameraMetadata(name: model, nameNormalized: model.uppercased(), make: nil, model: model)
        case (let make?, let model?):
            let name: String

            // Some cameras repeat the manufacturer at the beginning of the model.
            // Remove that prefix before joining the values to avoid names such as
            // "Fujifilm FUJIFILM X-T5".
            if let makeRange = model.range(of: make, options: [.anchored, .caseInsensitive]) {
                let modelWithoutMake = self.normalized(String(model[makeRange.upperBound...]))
                name = [make, modelWithoutMake].compactMap { $0 }.joined(separator: " ")
            } else {
                name = "\(make) \(model)"
            }

            return CameraMetadata(name: name, nameNormalized: name.uppercased(), make: make, model: model)
        }
    }

    private static func unique(_ values: [Int64]) -> [Int64] {
        // Remove duplicates while preserving the original identifier order.
        var seen: Set<Int64> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func normalized(_ value: String?) -> String? {
        // Treat missing, empty and space-only EXIF values in the same way.
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        return normalized.isEmpty ? nil : normalized
    }

    private static func contributesToAmount(_ visibility: StatusVisibility?) -> Bool {
        // Amount represents photos available through public metadata timelines.
        visibility == .public || visibility == .quietPublic
    }

    private static func cameraAmounts(from exifItems: [ExifTimelineMetadata]) -> [String: Int] {
        // Count photos per normalized camera name; a status may contain several
        // photos made with the same camera.
        var amounts: [String: Int] = [:]
        for exif in exifItems {
            guard let camera = self.cameraMetadata(make: exif.make, model: exif.model) else {
                continue
            }

            amounts[camera.nameNormalized, default: 0] += 1
        }

        return amounts
    }

    private static func lensAmounts(from exifItems: [ExifTimelineMetadata]) -> [String: Int] {
        // Reuse the generic normalized-name counter for lens values.
        self.amounts(from: exifItems.map(\.lens))
    }

    private static func filmAmounts(from exifItems: [ExifTimelineMetadata]) -> [String: Int] {
        // Reuse the generic normalized-name counter for film values.
        self.amounts(from: exifItems.map(\.film))
    }

    private static func amounts(from values: [String?]) -> [String: Int] {
        // Ignore empty metadata and group differently cased values under the same
        // normalized dictionary key.
        var amounts: [String: Int] = [:]
        for value in values {
            guard let nameNormalized = self.nameNormalized(value) else {
                continue
            }

            amounts[nameNormalized, default: 0] += 1
        }

        return amounts
    }

    private static func nameMetadata(from values: [String?]) -> [String: NameMetadata] {
        // Keep the first display spelling for each normalized value while removing
        // duplicate lens or film entries from the batch.
        var metadata: [String: NameMetadata] = [:]
        for value in values {
            guard let name = self.normalized(value) else {
                continue
            }

            let nameNormalized = name.uppercased()
            if metadata[nameNormalized] == nil {
                metadata[nameNormalized] = NameMetadata(name: name, nameNormalized: nameNormalized)
            }
        }

        return metadata
    }

    private func ensureCameras(_ metadata: [CameraMetadata], on context: ExecutionContext, sqlDatabase: SQLDatabase) async throws -> [Camera] {
        // Avoid generating an invalid empty IN query when no camera metadata exists.
        guard metadata.isEmpty == false else {
            return []
        }

        // Find dictionary rows that already represent the requested normalized names.
        let normalizedNames = metadata.map(\.nameNormalized)
        let existingCameras = try await Camera.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
        let existingNormalizedNames = Set(existingCameras.map(\.nameNormalized))
        let missingCameras = metadata.filter {
            existingNormalizedNames.contains($0.nameNormalized) == false
        }

        // Insert all missing cameras in one statement. The conflict clause protects
        // against another request inserting the same normalized name concurrently.
        if missingCameras.isEmpty == false {
            let insert = sqlDatabase
                .insert(into: Camera.schema)
                .columns("id", "name", "nameNormalized", "make", "model", "amount", "createdAt")

            for camera in missingCameras {
                insert.values(
                    context.services.snowflakeService.generate(),
                    camera.name,
                    camera.nameNormalized,
                    camera.make,
                    camera.model,
                    0,
                    Date()
                )
            }

            try await insert
                .ignoringConflicts(with: "nameNormalized")
                .run()
        }

        // Query again after the conflict-safe insert so the caller receives both
        // pre-existing rows and rows inserted by this or another request.
        return try await Camera.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
    }

    private func ensureLenses(_ metadata: [NameMetadata], on context: ExecutionContext, sqlDatabase: SQLDatabase) async throws -> [Lens] {
        // Avoid generating an invalid empty IN query when no lens metadata exists.
        guard metadata.isEmpty == false else {
            return []
        }

        // Find dictionary rows that already represent the requested normalized names.
        let normalizedNames = metadata.map(\.nameNormalized)
        let existingLenses = try await Lens.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
        let existingNormalizedNames = Set(existingLenses.map(\.nameNormalized))
        let missingMetadata = metadata.filter {
            existingNormalizedNames.contains($0.nameNormalized) == false
        }

        // Insert all missing lenses in one conflict-safe statement.
        if missingMetadata.isEmpty == false {
            let insert = sqlDatabase
                .insert(into: Lens.schema)
                .columns("id", "name", "nameNormalized", "amount", "createdAt")

            for lens in missingMetadata {
                insert.values(
                    context.services.snowflakeService.generate(),
                    lens.name,
                    lens.nameNormalized,
                    0,
                    Date()
                )
            }

            try await insert
                .ignoringConflicts(with: "nameNormalized")
                .run()
        }

        // Reload all requested rows, including any created concurrently.
        return try await Lens.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
    }

    private func ensureFilms(_ metadata: [NameMetadata], on context: ExecutionContext, sqlDatabase: SQLDatabase) async throws -> [Film] {
        // Avoid generating an invalid empty IN query when no film metadata exists.
        guard metadata.isEmpty == false else {
            return []
        }

        // Find dictionary rows that already represent the requested normalized names.
        let normalizedNames = metadata.map(\.nameNormalized)
        let existingFilms = try await Film.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
        let existingNormalizedNames = Set(existingFilms.map(\.nameNormalized))
        let missingMetadata = metadata.filter {
            existingNormalizedNames.contains($0.nameNormalized) == false
        }

        // Insert all missing films in one conflict-safe statement.
        if missingMetadata.isEmpty == false {
            let insert = sqlDatabase
                .insert(into: Film.schema)
                .columns("id", "name", "nameNormalized", "amount", "createdAt")

            for film in missingMetadata {
                insert.values(
                    context.services.snowflakeService.generate(),
                    film.name,
                    film.nameNormalized,
                    0,
                    Date()
                )
            }

            try await insert
                .ignoringConflicts(with: "nameNormalized")
                .run()
        }

        // Reload all requested rows, including any created concurrently.
        return try await Film.query(on: context.db)
            .filter(\.$nameNormalized ~~ normalizedNames)
            .all()
    }

    private func createCameraStatuses(statusId: Int64, normalizedNames: Set<String>, camerasByNormalizedName: [String: Camera], on sqlDatabase: SQLDatabase) async throws {
        // Resolve normalized names to persistent identifiers and skip values that
        // could not be represented by a dictionary row.
        let cameraIds = try normalizedNames
            .compactMap { camerasByNormalizedName[$0] }
            .map { try $0.requireID() }
        guard cameraIds.isEmpty == false else {
            return
        }

        // Insert all camera relationships in one conflict-safe statement.
        let insert = sqlDatabase
            .insert(into: CameraStatus.schema)
            .columns("cameraId", "statusId")

        for cameraId in cameraIds {
            insert.values(cameraId, statusId)
        }

        try await insert
            .ignoringConflicts(with: ["cameraId", "statusId"])
            .run()
    }

    private func createLensStatuses(statusId: Int64, normalizedNames: Set<String>, lensesByNormalizedName: [String: Lens], on sqlDatabase: SQLDatabase) async throws {
        // Resolve normalized names to persistent identifiers and skip values that
        // could not be represented by a dictionary row.
        let lensIds = try normalizedNames
            .compactMap { lensesByNormalizedName[$0] }
            .map { try $0.requireID() }
        guard lensIds.isEmpty == false else {
            return
        }

        // Insert all lens relationships in one conflict-safe statement.
        let insert = sqlDatabase
            .insert(into: LensStatus.schema)
            .columns("lensId", "statusId")

        for lensId in lensIds {
            insert.values(lensId, statusId)
        }

        try await insert
            .ignoringConflicts(with: ["lensId", "statusId"])
            .run()
    }

    private func createFilmStatuses(statusId: Int64, normalizedNames: Set<String>, filmsByNormalizedName: [String: Film], on sqlDatabase: SQLDatabase) async throws {
        // Resolve normalized names to persistent identifiers and skip values that
        // could not be represented by a dictionary row.
        let filmIds = try normalizedNames
            .compactMap { filmsByNormalizedName[$0] }
            .map { try $0.requireID() }
        guard filmIds.isEmpty == false else {
            return
        }

        // Insert all film relationships in one conflict-safe statement.
        let insert = sqlDatabase
            .insert(into: FilmStatus.schema)
            .columns("filmId", "statusId")

        for filmId in filmIds {
            insert.values(filmId, statusId)
        }

        try await insert
            .ignoringConflicts(with: ["filmId", "statusId"])
            .run()
    }

    private func updateCameraAmounts(previous: [String: Int], current: [String: Int], camerasByNormalizedName: [String: Camera], on sqlDatabase: SQLDatabase) async throws {
        // Visit names from both states so removed cameras are decremented and newly
        // added cameras are incremented.
        for normalizedName in Set(previous.keys).union(current.keys) {
            guard let cameraId = try camerasByNormalizedName[normalizedName]?.requireID() else {
                continue
            }

            // Persist only the net number of photos introduced by this change.
            try await self.updateAmount(
                table: Camera.schema,
                id: cameraId,
                by: current[normalizedName, default: 0] - previous[normalizedName, default: 0],
                on: sqlDatabase
            )
        }
    }

    private func updateLensAmounts(previous: [String: Int], current: [String: Int], lensesByNormalizedName: [String: Lens], on sqlDatabase: SQLDatabase) async throws {
        // Visit names from both states so removed lenses are decremented and newly
        // added lenses are incremented.
        for normalizedName in Set(previous.keys).union(current.keys) {
            guard let lensId = try lensesByNormalizedName[normalizedName]?.requireID() else {
                continue
            }

            // Persist only the net number of photos introduced by this change.
            try await self.updateAmount(
                table: Lens.schema,
                id: lensId,
                by: current[normalizedName, default: 0] - previous[normalizedName, default: 0],
                on: sqlDatabase
            )
        }
    }

    private func updateFilmAmounts(previous: [String: Int], current: [String: Int], filmsByNormalizedName: [String: Film], on sqlDatabase: SQLDatabase) async throws {
        // Visit names from both states so removed films are decremented and newly
        // added films are incremented.
        for normalizedName in Set(previous.keys).union(current.keys) {
            guard let filmId = try filmsByNormalizedName[normalizedName]?.requireID() else {
                continue
            }

            // Persist only the net number of photos introduced by this change.
            try await self.updateAmount(
                table: Film.schema,
                id: filmId,
                by: current[normalizedName, default: 0] - previous[normalizedName, default: 0],
                on: sqlDatabase
            )
        }
    }

    private func updateAmount(table: String, id: Int64, by difference: Int, on sqlDatabase: SQLDatabase) async throws {
        // Skip writes when the number of matching photos did not change.
        guard difference != 0 else {
            return
        }

        // Update the counter atomically and protect historical inconsistencies from
        // producing a negative amount.
        try await sqlDatabase.raw(
            """
            UPDATE \(ident: table)
            SET \(ident: "amount") = CASE
                WHEN \(ident: "amount") + \(bind: difference) < 0 THEN 0
                ELSE \(ident: "amount") + \(bind: difference)
            END
            WHERE \(ident: "id") = \(bind: id)
            """
        ).run()
    }
}
