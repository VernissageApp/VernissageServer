//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
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
