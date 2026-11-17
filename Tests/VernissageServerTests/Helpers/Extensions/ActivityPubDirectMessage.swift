//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Vapor
import VaporTesting
import Testing

func privateActivityPubNote(sender: User, recipients: [User], id: String? = nil, parent: String? = nil,
                            content: String = "<p>Private hello</p>", ccRecipients: [User] = []) -> NoteDto {
    let noteId = id ?? sender.activityPubProfile + "/statuses/" + UUID().uuidString

    return NoteDto(id: noteId, summary: nil, inReplyTo: parent, published: Date().toISO8601String(), updated: nil,
        url: noteId, attributedTo: sender.activityPubProfile, to: .multiple(recipients.map { ActorDto(id: $0.activityPubProfile) }),
        cc: ccRecipients.isEmpty ? nil : .multiple(ccRecipients.map { ActorDto(id: $0.activityPubProfile) }), sensitive: false, atomUri: nil, inReplyToAtomUri: nil, conversation: nil, content: content, attachment: nil, tag: nil)
}

extension Application {
    /// Posts an arbitrary signed ActivityPub activity through the real inbox and signature validation path.
    func receiveSignedPrivateActivity(_ activity: ActivityDto, sender: User,
                                      inbox: String = "/shared/inbox", invalidSignature: Bool = false) async throws -> TestingHTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let body = try encoder.encode(activity)
        var headers = [Header: String]().signature(actorId: sender.activityPubProfile,
            privateKeyPem: try #require(sender.privateKey), body: body, httpMethod: .post,
            httpPath: inbox, userAgent: Constants.userAgent, host: "localhost")

        if invalidSignature {
            headers[.signature] = "invalid"
        }

        return try await sendRequest(to: inbox, version: .none, method: .POST,
                                     headers: headers.getHTTPHeaders(), body: body)
    }

    func receivePrivateLike(statusActivityPubId: String, sender: User, favouriteId: String = "private-like",
                            undo: Bool = false, referenceOnly: Bool = false, embeddedActorId: String? = nil,
                            inbox: String = "/shared/inbox", invalidSignature: Bool = false) async throws -> TestingHTTPResponse {
        let likeId = sender.activityPubProfile + "#likes/" + favouriteId
        let object: ObjectDto

        if undo {
            object = referenceOnly ? ObjectDto(id: likeId) : ObjectDto(id: likeId, type: .like,
                object: LikeDto(id: likeId, actor: .single(ActorDto(id: embeddedActorId ?? sender.activityPubProfile)),
                                to: nil, cc: nil, object: .single(ObjectDto(id: statusActivityPubId))))
        } else {
            object = ObjectDto(id: statusActivityPubId)
        }

        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
            type: undo ? .undo : .like, id: undo ? likeId + "/undo" : likeId,
            actor: .single(ActorDto(id: sender.activityPubProfile)), object: .single(object), summary: nil, signature: nil)

        return try await receiveSignedPrivateActivity(activity, sender: sender, inbox: inbox, invalidSignature: invalidSignature)
    }

    func createRemoteDirectMessageUser() async throws -> User {
        let user = try await createUser(userName: "apdm" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                                       generateKeys: true, isLocal: false)
        user.userInbox = user.activityPubProfile + "/inbox"
        user.sharedInbox = "http://localhost:8080/shared/inbox"
        try await user.save(on: db)

        return user
    }

    /// Sends a real signed HTTP Create through either inbox endpoint, including its signature middleware/job.
    func receivePrivateActivityPubNote(_ note: NoteDto, sender: User, inbox: String = "/shared/inbox",
                                      envelopeTo: [String]? = nil, invalidSignature: Bool = false, activityType: ActivityTypeDto = .create) async throws -> TestingHTTPResponse {
        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")), type: activityType,
            id: note.id + "/activity", actor: .single(ActorDto(id: sender.activityPubProfile)),
            to: .multiple((envelopeTo ?? note.to?.actorIds() ?? []).map { ActorDto(id: $0) }), cc: nil,
            object: .single(ObjectDto(id: note.id, type: .note, object: note)), summary: nil, signature: nil, published: note.published)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let body = try encoder.encode(activity)
        var headers = [Header: String]().signature(actorId: sender.activityPubProfile, privateKeyPem: try #require(sender.privateKey),
            body: body, httpMethod: .post, httpPath: inbox, userAgent: Constants.userAgent, host: "localhost")

        if invalidSignature {
            headers[.signature] = "invalid"
        }

        return try await sendRequest(to: inbox, version: .none, method: .POST, headers: headers.getHTTPHeaders(), body: body)
    }
}
