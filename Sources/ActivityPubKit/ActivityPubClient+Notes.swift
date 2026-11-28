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
    /// Downloads a remote `Note` object by its URL.
    /// - Parameters:
    ///   - url: The full URL of the remote note.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: A deserialized `NoteDto` fetched from the remote server.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func note(url: URL, activityPubProfile: String) async throws -> NoteDto {
        let (data, response) = try await fetchNote(url: url, activityPubProfile: activityPubProfile)
        return try decodeNote(data: data, response: response, requestedURL: url)
    }

    /// Resolves a public post link and verifies the note at its canonical ActivityPub ID.
    /// - Parameters:
    ///   - url: The public URL of the remote post.
    ///   - activityPubProfile: The ActivityPub actor ID used to sign the requests.
    /// - Returns: The verified `NoteDto` for the canonical ActivityPub ID.
    /// - Throws: An error if client configuration is missing, a request fails, or the note cannot be verified.
    func note(publicURL url: URL, activityPubProfile: String) async throws -> NoteDto {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkingError.cannotCreateUrlRequest
        }
        components.fragment = nil
        guard let publicURL = components.url else {
            throw NetworkingError.cannotCreateUrlRequest
        }

        let (data, response) = try await fetchNote(url: publicURL, activityPubProfile: activityPubProfile)
        if let responseURL = response.url, self.isPublicNoteHTTPSUpgrade(from: publicURL, to: responseURL) {
            // A redirect can change the signed request target, so sign a new request for the HTTPS URL.
            // The upgrade only starts from HTTP, so this retry can happen at most once.
            return try await note(publicURL: responseURL, activityPubProfile: activityPubProfile)
        }

        let candidate = try decodeNoteResponse(data: data, response: response, requestedURL: publicURL)

        do {
            return try validateNote(candidate, requestedURL: publicURL)
        } catch NoteValidationError.objectIdMismatch {
            // Treat a same-origin ID from the public page as a lookup hint. Import the verified canonical response.
            guard candidate.type == "Note",
                  let canonicalURL = URL(string: candidate.id),
                  self.noteOrigin(canonicalURL) == self.noteOrigin(publicURL) else {
                throw NoteValidationError.objectIdMismatch
            }

            return try await note(url: canonicalURL, activityPubProfile: activityPubProfile)
        }
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
    ///   - recipientActorIds: Explicit private audience. Omit for a public status deletion.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func delete(actorId: String, statusId: String, on inbox: URL, recipientActorIds: [String]? = nil) async throws {
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
            target: ActivityPub.Notes.delete(actorId, statusId, privatePemKey, inbox.path, userAgent, host, recipientActorIds)
        )

        _ = try await downloadBody(request: request)
    }
    
    /// Sends a `Like` activity for a status to the target inbox.
    /// - Parameters:
    ///   - statusFavouriteId: The identifier used for the outgoing `Like` activity.
    ///   - activityPubStatusId: The ActivityPub id of the status being liked.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - inbox: The destination inbox URL.
    ///   - recipientActorIds: Explicit private audience; nil preserves the ordinary Like representation.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func like(statusFavouriteId: String, activityPubStatusId: String, activityPubProfile: String, on inbox: URL, recipientActorIds: [String]? = nil) async throws {
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
                                           host,
                                           recipientActorIds)
        )
        
        _ = try await downloadBody(request: request)
    }
    
    /// Sends an undo for a previous `Like` activity to the target inbox.
    /// - Parameters:
    ///   - statusFavouriteId: The identifier used for the outgoing undo activity.
    ///   - activityPubStatusId: The ActivityPub id of the status being unliked.
    ///   - activityPubProfile: The ActivityPub actor id used as the sender.
    ///   - inbox: The destination inbox URL.
    ///   - recipientActorIds: Explicit private audience for both Undo and its embedded Like.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func unlike(statusFavouriteId: String, activityPubStatusId: String, activityPubProfile: String, on inbox: URL, recipientActorIds: [String]? = nil) async throws {
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
                                             host,
                                             recipientActorIds)
        )
        
        _ = try await downloadBody(request: request)
    }

    internal func decodeNote(data: Data, response: URLResponse, requestedURL: URL) throws -> NoteDto {
        let note = try decodeNoteResponse(data: data, response: response, requestedURL: requestedURL)
        return try validateNote(note, requestedURL: requestedURL)
    }

    private func fetchNote(url: URL, activityPubProfile: String) async throws -> (Data, URLResponse) {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }

        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              self.noteOrigin(url) != nil,
              components.fragment == nil else {
            throw NetworkingError.cannotCreateUrlRequest
        }

        // Sign the path and query in their encoded form so the signature covers the target sent on the wire.
        var requestTarget = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            requestTarget += "?\(query)"
        }

        let request = try Self.request(
            forFullUrl: url,
            target: ActivityPub.Notes.get(activityPubProfile, privatePemKey, requestTarget, userAgent, host)
        )

        return try await urlSession.asyncData(for: request)
    }

    private func decodeNoteResponse(data: Data, response: URLResponse, requestedURL: URL) throws -> NoteDto {
        // The final response has to come from the origin authorized by the requested identifier.
        guard let requestedOrigin = self.noteOrigin(requestedURL),
              let responseURL = response.url,
              self.noteOrigin(responseURL) == requestedOrigin else {
            throw NoteValidationError.responseOriginMismatch
        }

        return try downloadJson(NoteDto.self, data: data, response: response)
    }

    private func validateNote(_ note: NoteDto, requestedURL: URL) throws -> NoteDto {
        guard note.id.utf8.elementsEqual(requestedURL.absoluteString.utf8) else {
            throw NoteValidationError.objectIdMismatch
        }

        guard let requestedOrigin = self.noteOrigin(requestedURL),
              let authorURL = URL(string: note.attributedTo),
              self.noteOrigin(authorURL) == requestedOrigin else {
            throw NoteValidationError.authorOriginMismatch
        }

        return note
    }

    private func noteOrigin(_ url: URL) -> NoteOrigin? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty, url.user == nil, url.password == nil else {
            return nil
        }

        return NoteOrigin(scheme: scheme, host: host, port: url.port ?? (scheme == "https" ? 443 : 80))
    }

    private func isPublicNoteHTTPSUpgrade(from requestedURL: URL, to responseURL: URL) -> Bool {
        guard let requestedOrigin = self.noteOrigin(requestedURL),
              let responseOrigin = self.noteOrigin(responseURL) else {
            return false
        }

        return requestedOrigin.scheme == "http" && requestedOrigin.port == 80
            && responseOrigin.scheme == "https" && responseOrigin.port == 443
            && requestedOrigin.host == responseOrigin.host
    }
}
