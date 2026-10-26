//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Vapor
import Testing

extension ControllersTests {
    @Suite("ActivityPubActors (POST /actors/:name/inbox [Create])", .serialized, .tags(.shared))
    struct ActivityPubActorsInboxCreateActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `An unknown personal inbox cannot receive messages on behalf of other users`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, inbox: "/actors/missing-dm-user/inbox")

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }

        @Test
        func `A private text note reaches its addressed personal inbox`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, inbox: "/actors/\(local.userName)/inbox")
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(status.$directConversation.id != nil)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == local.requireID())
                .count() == 1)
        }

        @Test
        func `Delivery to an unaddressed personal inbox does not create a private message`() async throws {
            // Arrange.
            let addressed = try await application.createDirectMessageUser()
            let other = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [addressed])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, inbox: "/actors/\(other.userName)/inbox")

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }
    }
}
