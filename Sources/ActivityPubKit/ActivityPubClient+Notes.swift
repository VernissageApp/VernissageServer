//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    /// Downloads a remote `Note` object by its URL.
    /// - Parameters:
    ///   - url: The full URL of the remote note.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: A deserialized `NoteDto` fetched from the remote server.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func note(url: URL, activityPubProfile: String) async throws -> NoteDto {
        
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: url,
            target: ActivityPub.Notes.get(activityPubProfile, privatePemKey, url.path, userAgent, host)
        )
        
        return try await downloadJson(NoteDto.self, request: request)
    }
    
    /// Sends a `Create` activity with the provided `Note` object to the target inbox.
    /// - Parameters:
    ///   - note: The note payload to publish.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - activityPubReplyProfile: Optional ActivityPub actor id used as the reply target context.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func create(note: NoteDto, activityPubProfile: String, activityPubReplyProfile: String?, on inbox: URL) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.create(
                note,
                activityPubProfile,
                activityPubReplyProfile,
                privatePemKey,
                inbox.path,
                userAgent,
                host
            )
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends an `Update` activity for an existing `Note` object to the target inbox.
    /// - Parameters:
    ///   - historyId: The identifier of the history revision used in the update activity id.
    ///   - published: The publication date included in the outgoing activity.
    ///   - note: The updated note payload.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - activityPubReplyProfile: Optional ActivityPub actor id used as the reply target context.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func update(historyId: String, published: Date, note: NoteDto, activityPubProfile: String, activityPubReplyProfile: String?, on inbox: URL) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.update(
                historyId,
                published,
                note,
                activityPubProfile,
                activityPubReplyProfile,
                privatePemKey,
                inbox.path,
                userAgent,
                host
            )
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends an `Announce` activity for a reblogged status to the target inbox.
    /// - Parameters:
    ///   - activityPubStatusId: The ActivityPub id of the local announce status.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - published: The publication date included in the outgoing activity.
    ///   - activityPubReblogProfile: The ActivityPub actor id of the original status owner.
    ///   - activityPubReblogStatusId: The ActivityPub id of the announced status.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func announce(
        activityPubStatusId: String,
        activityPubProfile: String,
        published: Date,
        activityPubReblogProfile: String,
        activityPubReblogStatusId: String,
        on inbox: URL
    ) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.announce(
                activityPubStatusId,
                activityPubProfile,
                published,
                activityPubReblogProfile,
                activityPubReblogStatusId,
                privatePemKey,
                inbox.path,
                userAgent,
                host
            )
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends an undo for a previous `Announce` activity to the target inbox.
    /// - Parameters:
    ///   - activityPubStatusId: The ActivityPub id of the local unannounce status.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - published: The publication date included in the outgoing activity.
    ///   - activityPubReblogProfile: The ActivityPub actor id of the original status owner.
    ///   - activityPubReblogStatusId: The ActivityPub id of the previously announced status.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func unannounce(
        activityPubStatusId: String,
        activityPubProfile: String,
        published: Date,
        activityPubReblogProfile: String,
        activityPubReblogStatusId: String,
        on inbox: URL
    ) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.unannounce(
                activityPubStatusId,
                activityPubProfile,
                published,
                activityPubReblogProfile,
                activityPubReblogStatusId,
                privatePemKey,
                inbox.path,
                userAgent,
                host
            )
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends a `Delete` activity for a status to the target inbox.
    /// - Parameters:
    ///   - actorId: The ActivityPub actor id used as the sender.
    ///   - statusId: The ActivityPub id of the status to delete.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func delete(actorId: String, statusId: String, on inbox: URL) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.delete(actorId, statusId, privatePemKey, inbox.path, userAgent, host)
        )

        _ = try await downloadBody(request: request)
    }
    
    /// Sends a `Like` activity for a status to the target inbox.
    /// - Parameters:
    ///   - statusFavouriteId: The identifier used for the outgoing `Like` activity.
    ///   - activityPubStatusId: The ActivityPub id of the status being liked.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func like(statusFavouriteId: String, activityPubStatusId: String, activityPubProfile: String, on inbox: URL) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.like(statusFavouriteId,
                                           activityPubProfile,
                                           activityPubStatusId,
                                           privatePemKey,
                                           inbox.path,
                                           userAgent,
                                           host)
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends an undo for a previous `Like` activity to the target inbox.
    /// - Parameters:
    ///   - statusFavouriteId: The identifier used for the outgoing undo activity.
    ///   - activityPubStatusId: The ActivityPub id of the status being unliked.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func unlike(statusFavouriteId: String, activityPubStatusId: String, activityPubProfile: String, on inbox: URL) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: inbox,
            target: ActivityPub.Notes.unlike(statusFavouriteId,
                                             activityPubProfile,
                                             activityPubStatusId,
                                             privatePemKey,
                                             inbox.path,
                                             userAgent,
                                             host)
        )
        
        _ = try await downloadBody(request: request)
    }
}
