//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Fluent
import Testing

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [Annouce])", .serialized, .tags(.shared))
    struct ActivityPubSharedAnnouceTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Announce cannot expose a received private photo to followers`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let follower = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let relay = try await application.createRemoteDirectMessageUser()
            _ = try await application.createFollow(sourceId: follower.requireID(), targetId: relay.requireID(), approved: true)
            let original = application.services.temporaryFileService
            application.services.temporaryFileService = FixtureTemporaryFileService(base: original)

            defer { application.services.temporaryFileService = original }
            let id = sender.activityPubProfile + "/statuses/" + UUID().uuidString
            let note = NoteDto(id: id, summary: nil, inReplyTo: nil, published: Date().toISO8601String(), updated: nil,
                url: id, attributedTo: sender.activityPubProfile, to: .single(ActorDto(id: local.activityPubProfile)), cc: nil,
                sensitive: false, atomUri: nil, inReplyToAtomUri: nil, conversation: nil, content: "Private photo",
                attachment: [MediaAttachmentDto(mediaType: "image/png", url: FixtureTemporaryFileService.imageUrl, name: nil,
                    blurhash: nil, width: 1706, height: 882, hdrImageUrl: nil, exif: nil, exifData: nil, location: nil)], tag: nil)
            _ = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == id)
                .first())
            let attachment = try await application.getAttachment(userId: sender.requireID())

            defer { application.clearFiles(attachments: [attachment]) }

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: relay,
                envelopeTo: ["https://www.w3.org/ns/activitystreams#Public"], activityType: .announce)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$reblog.$id == status.requireID())
                .count() == 0)
            #expect(try await UserStatus.query(on: application.db)
                .filter(\.$user.$id == follower.requireID())
                .count() == 0)
            #expect(try await Status.find(status.requireID(), on: application.db)?.reblogsCount == 0)
        }
    }
}
