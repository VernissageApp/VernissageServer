//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import ZIPFoundation
import ActivityPubKit

extension Application.Services {
    struct ArchivesServiceKey: StorageKey {
        typealias Value = ArchivesServiceType
    }

    var archivesService: ArchivesServiceType {
        get {
            self.application.storage[ArchivesServiceKey.self] ?? ArchivesService()
        }
        nonmutating set {
            self.application.storage[ArchivesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ArchivesServiceType: Sendable {
    /// Creates a user data archive with all associated files and uploads it to storage.
    /// - Parameters:
    ///   - archiveId: The unique identifier for the archive to be generated.
    ///   - context: The queue execution context.
    /// - Throws: Errors encountered during archive creation, file operations, or uploading.
    func create(for archiveId: Int64, on context: QueueContext) async throws

    /// Deletes a user data archive from storage and marks it as expired in the system.
    /// - Parameters:
    ///   - archiveId: The unique identifier for the archive to be deleted.
    ///   - context: The queue execution context.
    /// - Throws: Errors encountered during archive deletion or storage operations.
    func delete(for archiveId: Int64, on context: QueueContext) async throws
}

/// A service for managing archives in the system.
final class ArchivesService: ArchivesServiceType {
    let encoder: JSONEncoder
    
    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .customISO8601
        
        self.encoder = encoder
    }
        
    func create(for archiveId: Int64, on context: QueueContext) async throws {
        context.logger.info("Creating new archive for '\(archiveId)' started.")
        
        guard let archiveFromDatabase = try await Archive.query(on: context.application.db)
            .with(\.$user)
            .filter(\.$id == archiveId)
            .first() else {
            context.logger.info("Archive with id '\(archiveId)' not exists.")
            return
        }

        // Mark Archive as during processing.
        archiveFromDatabase.status = .processing
        archiveFromDatabase.startDate = Date()
        try await archiveFromDatabase.save(on: context.application.db)

        // Create folder for all user's data files.
        let archiveFolder = try await createArchiveDirectory(archiveId: archiveId, on: context)
        
        // Create actor.json file.
        let personDto = try await saveActorFile(archiveId: archiveId, user: archiveFromDatabase.user, on: context)
        
        // Create avatar.jpeg file.
        try await saveAvatarFile(archiveId: archiveId, personDto: personDto, on: context)
        
        // Create header.jpeg file.
        try await saveHeaderFile(archiveId: archiveId, personDto: personDto, on: context)
        
        // Create bookmarks.json file.
        try await saveBookmarksFile(archiveId: archiveId, userId: archiveFromDatabase.user.requireID(), on: context)
        
        // Create likes.json file.
        try await saveFavouritesFile(archiveId: archiveId, userId: archiveFromDatabase.user.requireID(), on: context)
        
        // Create outbox.json file (with statuses).
        let noteDtos = try await saveStatusesFile(archiveId: archiveId, userId: archiveFromDatabase.user.requireID(), on: context)
        
        // Download all attachments to media_attachments folder.
        try await downloadMediaAttachments(archiveId: archiveId, noteDtos: noteDtos, on: context)
        
        // Compress user folder to ZIP file.
        let archiveZipUrl = try await compressArchiveDirectory(archiveId: archiveId, archiveFolder: archiveFolder, on: context)
        
        // Send ZIP file to S3 Storage.
        let savedFileName = try await sendArchiveToStorage(archiveZipUrl: archiveZipUrl, on: context)

        // Mark archive as successfully generated.
        archiveFromDatabase.status = .ready
        archiveFromDatabase.endDate = Date()
        archiveFromDatabase.fileName = savedFileName
        try await archiveFromDatabase.save(on: context.application.db)

        // Send email with link to the archive.
        try await sendEmailWithArchiveUrl(archive: archiveFromDatabase, on: context)
        
        // Delete folder and ZIP file from file system.
        await deleteArchiveFromTemporaryFolder(archiveId: archiveId, archiveZipUrl: archiveZipUrl, on: context)
        
        context.logger.info("Creating new archive for '\(archiveId)' finished.")
    }
    
    func delete(for archiveId: Int64, on context: QueueContext) async throws {
        context.logger.info("Deleting archive for '\(archiveId)' started.")

        guard let archiveFromDatabase = try await Archive.query(on: context.application.db)
            .filter(\.$id == archiveId)
            .first() else {
            context.logger.info("Archive with id '\(archiveId)' not exists.")
            return
        }
        
        // Delete ZIP file from S3 storage.
        if let fileName = archiveFromDatabase.fileName {
            let storageService = context.application.services.storageService
            try await storageService.delete(fileName: fileName, on: context.executionContext)
        }

        // Mark archive as expired.
        archiveFromDatabase.status = .expired
        try await archiveFromDatabase.save(on: context.application.db)
        
        context.logger.info("Deleting archive for '\(archiveId)' finished.")
    }
    
    private func compressArchiveDirectory(archiveId: Int64, archiveFolder: String, on context: QueueContext) async throws -> URL {
        let temporaryFileService = context.application.services.temporaryFileService
        let archiveZip = try temporaryFileService.temporaryPath(based: "\(archiveId).zip", on: context.executionContext)
        let archiveFolderUrl = URL(fileURLWithPath: archiveFolder, isDirectory: true)
        let archiveZipUrl = URL(fileURLWithPath: archiveZip.absoluteString, isDirectory: false)
        
        context.logger.info("Compress folder: '\(archiveFolderUrl)' as a ZIP file: \(archiveZipUrl).")
        try FileManager.default.zipItem(at: archiveFolderUrl, to: archiveZipUrl)
        
        return archiveZipUrl
    }
    
    private func createArchiveDirectory(archiveId: Int64, on context: QueueContext) async throws -> String {
        context.logger.info("Removing old temporary folder '\(archiveId)'.")
        let temporaryFileService = context.application.services.temporaryFileService

        do {
            try await temporaryFileService.remove(folder: "\(archiveId)", on: context.executionContext)
        } catch {
            context.logger.warning("Old temporary folder '\(archiveId)' not deleted. Error: \(error)")
        }
        
        context.logger.info("Creating new temporary folder '\(archiveId)'.")
        let archiveFolder = try await temporaryFileService.create(folder: "\(archiveId)", on: context.executionContext)
        
        context.logger.info("Creating new media_attachments folder in temporary folder '\(archiveId)'.")
        _ = try await temporaryFileService.create(folder: "\(archiveId)/media_attachments", on: context.executionContext)
        
        return archiveFolder
    }
    
    private func saveActorFile(archiveId: Int64, user: User, on context: QueueContext) async throws -> PersonDto {
        context.logger.info("Creating actor.json file for archive: '\(archiveId)'.")
        
        let usersService = context.application.services.usersService
        let temporaryFileService = context.application.services.temporaryFileService
        
        let personDto = try await usersService.getPersonDto(for: user, on: context.executionContext)
        let personDtoData = try encoder.encode(personDto)
        try await temporaryFileService.save(path: "\(archiveId)/actor.json",
                                            byteBuffer: ByteBuffer(bytes: personDtoData),
                                            on: context.executionContext)
        
        return personDto
    }

    private func saveAvatarFile(archiveId: Int64, personDto: PersonDto, on context: QueueContext) async throws {
        if let icon = personDto.icon?.images().first {
            context.logger.info("Creating avatar image file for archive: '\(archiveId)'.")
            let temporaryFileService = context.application.services.temporaryFileService

            // Download avatar file.
            let filePath = try await temporaryFileService.save(url: icon.url, toFolder: "\(archiveId)", on: context.executionContext)
            
            // Rename file with correct extension.
            let pathExtension = icon.url.pathExtension ?? "jpg"
            try await temporaryFileService.moveFile(atPath: filePath.absoluteString,
                                                    toPath: "\(archiveId)/avatar.\(pathExtension)",
                                                    on: context.executionContext)
        }
    }
    
    private func saveHeaderFile(archiveId: Int64, personDto: PersonDto, on context: QueueContext) async throws {
        if let icon = personDto.image?.images().first {
            context.logger.info("Creating header image file for archive: '\(archiveId)'.")
            let temporaryFileService = context.application.services.temporaryFileService
            
            // Download header file.
            let filePath = try await temporaryFileService.save(url: icon.url, toFolder: "\(archiveId)", on: context.executionContext)

            // Rename file with correct extension.
            let pathExtension = icon.url.pathExtension ?? "jpg"
            try await temporaryFileService.moveFile(atPath: filePath.absoluteString,
                                                    toPath: "\(archiveId)/header.\(pathExtension)",
                                                    on: context.executionContext)
        }
    }
    
    private func saveBookmarksFile(archiveId: Int64, userId: Int64, on context: QueueContext) async throws {
        context.logger.info("Creating bookmarks.json file for archive: '\(archiveId)'.")
        
        let bookmarks = try await StatusBookmark.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .with(\.$status)
            .sort(\.$createdAt, .descending)
            .all()
        
        let bookmarkActivityPubIds = bookmarks.map { $0.status.activityPubId }
        let bookmarkActivityPubIdsData = try encoder.encode(bookmarkActivityPubIds)
        
        let temporaryFileService = context.application.services.temporaryFileService
        try await temporaryFileService.save(path: "\(archiveId)/bookmarks.json",
                                            byteBuffer: ByteBuffer(bytes: bookmarkActivityPubIdsData),
                                            on: context.executionContext)
    }
    
    private func saveFavouritesFile(archiveId: Int64, userId: Int64, on context: QueueContext) async throws {
        context.logger.info("Creating likes.json file for archive: '\(archiveId)'.")

        let favourites = try await StatusFavourite.query(on: context.application.db)
            .filter(\.$user.$id == userId)
            .with(\.$status)
            .sort(\.$createdAt, .descending)
            .all()
        
        let favouriteActivityPubIds = favourites.map { $0.status.activityPubId }
        let favouriteActivityPubIdsData = try encoder.encode(favouriteActivityPubIds)
        
        let temporaryFileService = context.application.services.temporaryFileService
        try await temporaryFileService.save(path: "\(archiveId)/likes.json",
                                            byteBuffer: ByteBuffer(bytes: favouriteActivityPubIdsData),
                                            on: context.executionContext)
    }
    
    private func saveStatusesFile(archiveId: Int64, userId: Int64, on context: QueueContext) async throws -> [NoteDto] {
        context.logger.info("Creating outbox.json file for archive: '\(archiveId)'.")
        let statusesService = context.application.services.statusesService

        let statuses = try await statusesService.all(userId: userId, on: context.application.db)
        let notesDto = try await statuses.asyncMap { try await statusesService.note(basedOn: $0, replyToStatus: nil, on: context.executionContext) }
        
        let notesDtoData = try encoder.encode(notesDto)
        
        let temporaryFileService = context.application.services.temporaryFileService
        try await temporaryFileService.save(path: "\(archiveId)/outbox.json",
                                            byteBuffer: ByteBuffer(bytes: notesDtoData),
                                            on: context.executionContext)
        
        return notesDto
    }
    
    private func downloadMediaAttachments(archiveId: Int64, noteDtos: [NoteDto], on context: QueueContext) async throws {
        context.logger.info("Downloading attachments for archive: '\(archiveId)' number of statuses: \(noteDtos.count).")

        for (index, noteDto) in noteDtos.enumerated() {
            context.logger.info("Downloading attachment \(index + 1)/\(noteDtos.count) for archive: '\(archiveId)'.")
            try await downloadMediaAttachment(archiveId: archiveId, noteDto: noteDto, on: context)
        }
    }
    
    private func downloadMediaAttachment(archiveId: Int64, noteDto: NoteDto, on context: QueueContext) async throws {
        guard let attachments = noteDto.attachment else {
            return
        }
        
        for attachment in attachments {
            let temporaryFileService = context.application.services.temporaryFileService
            _ = try await temporaryFileService.save(url: attachment.url, toFolder: "\(archiveId)/media_attachments/", on: context.executionContext)
        }
    }
    
    private func sendArchiveToStorage(archiveZipUrl: URL, on context: QueueContext) async throws -> String {
        context.logger.info("Sending archive: '\(archiveZipUrl.lastPathComponent)' to storage.")

        let storageService = context.application.services.storageService
        let fileName = try await storageService.save(fileName: archiveZipUrl.lastPathComponent, url: archiveZipUrl, on: context.executionContext)

        return fileName
    }
    
    private func deleteArchiveFromTemporaryFolder(archiveId: Int64, archiveZipUrl: URL, on context: QueueContext) async {
        let temporaryFileService = context.application.services.temporaryFileService

        context.logger.info("Deleting temporary zip file: '\(archiveZipUrl)'.")
        try? await temporaryFileService.delete(url: archiveZipUrl, on: context.executionContext)
        
        context.logger.info("Deleting temporary folder for archive: '\(archiveId)'.")
        try? await temporaryFileService.remove(folder: "\(archiveId)", on: context.executionContext)
    }
    
    private func sendEmailWithArchiveUrl(archive: Archive, on context: QueueContext) async throws {
        let emailsService = context.application.services.emailsService
        try await emailsService.dispatchArchiveReadyEmail(archive: archive, on: context.executionContext)
    }
}
