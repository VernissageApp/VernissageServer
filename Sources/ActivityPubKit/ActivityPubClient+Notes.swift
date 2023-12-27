//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    func note(url: URL) async throws -> NoteDto {
        let request = try Self.request(
            for: url,
            target: ActivityPub.Notes.get
        )
        
        return try await downloadJson(NoteDto.self, request: request)
    }
    
    func create(note: NoteDto, activityPubProfile: String, on inbox: URL) async throws {
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
            target: ActivityPub.Notes.create(note, activityPubProfile, privatePemKey, inbox.path, userAgent, host)
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
}
