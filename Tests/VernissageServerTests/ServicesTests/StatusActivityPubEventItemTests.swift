//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues
import Fluent

@Suite("StatusActivityPubEventItem", .serialized)
struct StatusActivityPubEventItemTests {

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `New event item should not be suspended by default`() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "dafnebenny")
        let attachment = try await application.createAttachment(user: user)
        let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
        defer {
            application.clearFiles(attachments: [attachment])
        }

        let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(),
                                                                       userId: user.requireID(),
                                                                       type: .create,
                                                                       numberOfSuccessItems: 1)

        // Act.
        let eventItem = try #require(await StatusActivityPubEventItem.query(on: application.db)
            .filter(\.$statusActivityPubEvent.$id == event.requireID())
            .first())

        // Assert.
        #expect(eventItem.isSuspended == false, "New event item should not be suspended.")
    }

    @Test
    func `Suspended function should mark item as suspended without error message`() async throws {
        // Arrange.
        let user = try await application.createUser(userName: "jaroslawbenny")
        let attachment = try await application.createAttachment(user: user)
        let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
        defer {
            application.clearFiles(attachments: [attachment])
        }

        let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(),
                                                                       userId: user.requireID(),
                                                                       type: .create,
                                                                       numberOfSuccessItems: 1)

        let eventItem = try #require(await StatusActivityPubEventItem.query(on: application.db)
            .filter(\.$statusActivityPubEvent.$id == event.requireID())
            .first())

        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))

        // Act.
        try await eventItem.suspended(on: queueContext.executionContext)

        // Assert.
        let eventItemFromDatabase = try #require(await StatusActivityPubEventItem.query(on: application.db)
            .filter(\.$id == eventItem.requireID())
            .first())

        #expect(eventItemFromDatabase.isSuccess == nil, "Suspended item should not be marked as failed.")
        #expect(eventItemFromDatabase.isSuspended == true, "Suspended item should be marked as suspended.")
        #expect(eventItemFromDatabase.errorMessage == nil, "Suspended item should not contain error message.")
        #expect(eventItemFromDatabase.endAt != nil, "Suspended item should have end date set.")
    }
}
