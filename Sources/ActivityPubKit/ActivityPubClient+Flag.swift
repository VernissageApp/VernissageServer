//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension ActivityPubClient {
    
    /// Sends a `Flag` activity to a remote server inbox.
    /// - Parameters:
    ///   - reportedActorId: The ActivityPub actor id being reported.
    ///   - reportedObjectIds: ActivityPub object ids related to the report (for example statuses).
    ///   - content: Optional report description included in the activity.
    ///   - actorId: The ActivityPub actor id of the reporting user.
    ///   - inbox: The target inbox URL, preferably a shared inbox when available.
    ///   - id: The activity identifier suffix used to build the outgoing `Flag` id.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func flag(
        reportedActorId: String,
        reportedObjectIds: [String] = [],
        content: String? = nil,
        by actorId: String,
        on inbox: URL,
        withId id: String
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
            target: ActivityPub.Flag.create(
                id,
                actorId,
                reportedActorId,
                reportedObjectIds,
                content,
                privatePemKey,
                inbox.path,
                userAgent,
                host
            )
        )

        _ = try await downloadBody(request: request)
    }
}
