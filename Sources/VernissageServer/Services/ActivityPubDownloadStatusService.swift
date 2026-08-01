//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import ActivityPubKit
import SwiftSoup

extension Application.Services {
    struct ActivityPubDownloadStatusServiceKey: StorageKey {
        typealias Value = ActivityPubDownloadStatusServiceType
    }

    var activityPubDownloadStatusService: ActivityPubDownloadStatusServiceType {
        get {
            self.application.storage[ActivityPubDownloadStatusServiceKey.self] ?? ActivityPubDownloadStatusService()
        }
        nonmutating set {
            self.application.storage[ActivityPubDownloadStatusServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubDownloadStatusServiceType: Sendable {
    /// Downloads a status by its ActivityPub ID.
    ///
    /// The method first checks the local database and returns the existing status when it is already stored.
    /// When the status is missing, it downloads the remote ActivityPub note, validates that the author is not blocked
    /// and that the note contains supported image attachments, downloads the author profile if needed, and stores the status locally.
    ///
    /// - Parameters:
    ///   - activityPubId: The ActivityPub ID (URL) of the status to download.
    ///   - context: The execution context providing services and database access.
    /// - Returns: The downloaded or existing local `Status` object.
    /// - Throws: Throws an error if the status cannot be downloaded or processed.
    func download(activityPubId: String, on context: ExecutionContext) async throws -> Status
}

final class ActivityPubDownloadStatusService: ActivityPubDownloadStatusServiceType {

    public func download(activityPubId: String, on context: ExecutionContext) async throws -> Status {
        let statusesService = context.services.statusesService
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let instanceBlockedUsersService = context.services.instanceBlockedUsersService
        let usersService = context.services.usersService

        // When we already have status in database we don't have to download it.
        if let status = try await statusesService.get(activityPubId: activityPubId, on: context.db) {
            return status
        }

        // Download status JSON from remote server (via ActivityPub endpoints).
        context.logger.info("Downloading status from remote server: '\(activityPubId)'.")
        let noteDto = try await self.downloadRemoteStatus(activityPubId: activityPubId, on: context)

        // Verify once again if status not exist in database.
        if let status = try await statusesService.get(activityPubId: noteDto.id, on: context.db) {
            return status
        }

        // We cannot save statuses from blocked actors (via announce or search).
        if try await instanceBlockedUsersService.isActorBlockedByInstance(activityPubId: noteDto.attributedTo, on: context) {
            context.logger.info("Actor (\(noteDto.attributedTo)) of downloaded status is blocked by the instance.")
            throw ActivityPubError.actorIsBlockedByInstance(noteDto.attributedTo)
        }

        // We cannot save statuses from suppressed actors (via announce or search).
        let noteAuthorFromDatabase = try await usersService.get(activityPubProfile: noteDto.attributedTo, on: context.db)
        if let noteAuthorFromDatabase, noteAuthorFromDatabase.isSuppressed {
            context.logger.warning("Status '\(noteDto.id)' from suppressed user '\(noteDto.attributedTo)' will not be added to the system.")
            throw ActivityPubError.actorIsSuppressedByInstance(noteDto.attributedTo)
        }

        guard let attachments = noteDto.attachment, !attachments.isEmpty, attachments.hasSupportedImages() else {
            context.logger.warning("Object doesn't contain any supported image media type attachments (status: \(noteDto.id), media types: '\(noteDto.attachment?.mediaTypes() ?? "")').")
            throw ActivityPubError.missingSupportedImageAttachments(activityPubId)
        }

        // Download user data to local database.
        context.logger.info("Downloading user profile from remote server: '\(noteDto.attributedTo)'.")
        let remoteUser = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: noteDto.attributedTo, on: context)

        guard let remoteUser else {
            await context.logger.store("Account '\(noteDto.attributedTo)' cannot be downloaded from remote server.", nil, on: context.application)
            throw ActivityPubError.actorNotDownloaded(noteDto.attributedTo)
        }

        // Create status in database.
        context.logger.info("Creating status in local database: '\(activityPubId)'.")
        let status = try await statusesService.create(basedOn: noteDto,
                                                      userId: remoteUser.requireID(),
                                                      visibility: .public,
                                                      on: context)

        // Recalculate numer of user statuses.
        try await statusesService.updateStatusCount(for: remoteUser.requireID(), on: context.db)

        return status
    }
    
    private func downloadRemoteStatus(activityPubId: String, on context: ExecutionContext) async throws -> NoteDto {
        guard let noteUrl = URL(string: activityPubId) else {
            await context.logger.store("Invalid URL to note: '\(activityPubId)'.", nil, on: context.application)
            throw ActivityPubError.invalidNoteUrl(activityPubId)
        }

        let usersService = context.services.usersService
        guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: context.db) else {
            throw ActivityPubError.missingInstanceAdminAccount
        }

        guard let privateKey = defaultSystemUser.privateKey else {
            throw ActivityPubError.missingInstanceAdminPrivateKey
        }

        do {
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: noteUrl.host)
            return try await activityPubClient.note(url: noteUrl, activityPubProfile: defaultSystemUser.activityPubProfile)
        } catch let networkError as NetworkError {
            let networkErrorDescription: String

            if let localizedDescription = networkError.errorDescription, !localizedDescription.isEmpty {
                networkErrorDescription = localizedDescription
            } else {
                networkErrorDescription = String(describing: networkError)
            }

            context.logger.warning("Error during download status: '\(activityPubId)'. Error: \(networkErrorDescription)")
            throw ActivityPubError.statusHasNotBeenDownloaded(activityPubId, networkErrorDescription)
        } catch {
            let errorDescription: String

            if let localizedError = error as? LocalizedError,
               let localizedDescription = localizedError.errorDescription,
               !localizedDescription.isEmpty {
                errorDescription = localizedDescription
            } else {
                errorDescription = String(describing: error)
            }

            context.logger.warning("Error during processing status: '\(activityPubId)'. Error: \(errorDescription)")
            throw ActivityPubError.statusCannotBeProcessed(activityPubId, errorDescription)
        }
    }

}
