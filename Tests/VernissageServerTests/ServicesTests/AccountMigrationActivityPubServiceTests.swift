//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Queues
import Testing
import Vapor

@Suite("AccountMigrationActivityPubService", .serialized)
struct AccountMigrationActivityPubServiceTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Move should be sent only once when duplicate jobs process the same item`() async throws {
        let sourceUser = try await application.createUser(userName: "migrationmovesuccesssource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "migrationmovesuccesstarget", isLocal: false)
        let (event, item) = try await self.createMoveEvent(sourceUser: sourceUser,
                                                         targetUser: targetUser,
                                                         inbox: "https://remote-success.example/inbox")
        let outgoingMigrationService = MockActivityPubOutgoingMigrationService(response: .success)
        let service = AccountMigrationActivityPubService(outgoingMigrationService: outgoingMigrationService)
        let context = application.getQueueContext(queueName: .apMoveRequester).executionContext

        async let first: Void = service.processMove(itemId: item.requireID(), on: context)
        async let second: Void = service.processMove(itemId: item.requireID(), on: context)
        _ = try await (first, second)

        let storedItem = try #require(try await MigrationMoveActivityPubEventItem.find(item.requireID(), on: application.db))
        let storedEvent = try #require(try await MigrationMoveActivityPubEvent.find(event.requireID(), on: application.db))
        #expect(storedItem.status == .succeeded)
        #expect(storedItem.attempts == 1)
        #expect(storedEvent.result == .finished)
        #expect(await outgoingMigrationService.moveIds() == [try event.requireID()])
    }

    @Test
    func `Gone response should finish Move item without retry`() async throws {
        let sourceUser = try await application.createUser(userName: "migrationmovegonesource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "migrationmovegonetarget", isLocal: false)
        let (event, item) = try await self.createMoveEvent(sourceUser: sourceUser,
                                                         targetUser: targetUser,
                                                         inbox: "https://remote-gone.example/inbox")
        let outgoingMigrationService = MockActivityPubOutgoingMigrationService(response: .httpStatus(410))
        let service = AccountMigrationActivityPubService(outgoingMigrationService: outgoingMigrationService)
        let context = application.getQueueContext(queueName: .apMoveRequester).executionContext

        try await service.processMove(itemId: item.requireID(), on: context)

        let storedItem = try #require(try await MigrationMoveActivityPubEventItem.find(item.requireID(), on: application.db))
        let storedEvent = try #require(try await MigrationMoveActivityPubEvent.find(event.requireID(), on: application.db))
        #expect(storedItem.status == .permanentFailure)
        #expect(storedItem.attempts == 1)
        #expect(storedItem.httpStatusCode == 410)
        #expect(storedItem.nextAttemptAt == nil)
        #expect(storedEvent.result == .finishedWithErrors)
        #expect(await outgoingMigrationService.moveIds().count == 1)
    }

    @Test
    func `Gone response from one inbox should not stop other Move deliveries`() async throws {
        let sourceUser = try await application.createUser(userName: "migrationmovepartialsource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "migrationmovepartialtarget", isLocal: false)
        let (event, goneItem) = try await self.createMoveEvent(sourceUser: sourceUser,
                                                              targetUser: targetUser,
                                                              inbox: "https://remote-partial-gone.example/inbox")
        let successfulItemId = application.services.snowflakeService.generate()
        let successfulItem = MigrationMoveActivityPubEventItem(id: successfulItemId,
                                                                migrationMoveActivityPubEventId: try event.requireID(),
                                                                inbox: "https://remote-partial-success.example/inbox")
        try await successfulItem.save(on: application.db)

        let outgoingMigrationService = MockActivityPubOutgoingMigrationService(responsesByHost: [
            "remote-partial-gone.example": .httpStatus(410),
            "remote-partial-success.example": .success
        ])
        let service = AccountMigrationActivityPubService(outgoingMigrationService: outgoingMigrationService)
        let context = application.getQueueContext(queueName: .apMoveRequester).executionContext

        try await service.processMove(itemId: goneItem.requireID(), on: context)
        try await service.processMove(itemId: successfulItemId, on: context)

        let storedGoneItem = try #require(try await MigrationMoveActivityPubEventItem.find(goneItem.requireID(), on: application.db))
        let storedSuccessfulItem = try #require(try await MigrationMoveActivityPubEventItem.find(successfulItemId, on: application.db))
        let storedEvent = try #require(try await MigrationMoveActivityPubEvent.find(event.requireID(), on: application.db))
        #expect(storedGoneItem.status == .permanentFailure)
        #expect(storedGoneItem.httpStatusCode == 410)
        #expect(storedSuccessfulItem.status == .succeeded)
        #expect(storedEvent.result == .finishedWithErrors)
        #expect(await outgoingMigrationService.moveIds().count == 2)
    }

    @Test
    func `Temporary Move failure should stop after three attempts and preserve activity id`() async throws {
        let sourceUser = try await application.createUser(userName: "migrationmoveretrysource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "migrationmoveretrytarget", isLocal: false)
        let (event, item) = try await self.createMoveEvent(sourceUser: sourceUser,
                                                         targetUser: targetUser,
                                                         inbox: "https://remote-retry.example/inbox")
        let outgoingMigrationService = MockActivityPubOutgoingMigrationService(response: .httpStatus(503))
        let service = AccountMigrationActivityPubService(outgoingMigrationService: outgoingMigrationService)
        let context = application.getQueueContext(queueName: .apMoveRequester).executionContext

        for attempt in 1...3 {
            try await service.processMove(itemId: item.requireID(), on: context)

            let storedItem = try #require(try await MigrationMoveActivityPubEventItem.find(item.requireID(), on: application.db))
            #expect(storedItem.attempts == attempt)
            #expect(storedItem.httpStatusCode == 503)

            if attempt < 3 {
                #expect(storedItem.status == .retryWaiting)
                storedItem.nextAttemptAt = Date.distantPast
                try await storedItem.save(on: application.db)
            } else {
                #expect(storedItem.status == .permanentFailure)
                #expect(storedItem.nextAttemptAt == nil)
            }
        }

        let eventId = try event.requireID()
        #expect(await outgoingMigrationService.moveIds() == [eventId, eventId, eventId])
    }

    @Test
    func `Follow item should persist successful delivery`() async throws {
        let migrationSource = try await application.createUser(userName: "migrationfollowsource", isLocal: false)
        let migrationTarget = try await application.createUser(userName: "migrationfollowtarget", isLocal: false)
        let actor = try await application.createUser(userName: "migrationfollowactor", generateKeys: true)
        let eventId = application.services.snowflakeService.generate()
        let itemId = application.services.snowflakeService.generate()
        let activityId = application.services.snowflakeService.generate()
        let event = MigrationFollowActivityPubEvent(id: eventId,
                                                    sourceUserId: try migrationSource.requireID(),
                                                    targetUserId: try migrationTarget.requireID(),
                                                    source: migrationSource.activityPubProfile,
                                                    target: migrationTarget.activityPubProfile)
        let item = MigrationFollowActivityPubEventItem(id: itemId,
                                                       migrationFollowActivityPubEventId: eventId,
                                                       actorUserId: try actor.requireID(),
                                                       type: .follow,
                                                       source: actor.activityPubProfile,
                                                       target: migrationTarget.activityPubProfile,
                                                       inbox: "https://remote-follow.example/inbox",
                                                       activityId: activityId)
        try await event.save(on: application.db)
        try await item.save(on: application.db)
        let outgoingMigrationService = MockActivityPubOutgoingMigrationService(response: .success)
        let service = AccountMigrationActivityPubService(outgoingMigrationService: outgoingMigrationService)
        let context = application.getQueueContext(queueName: .apFollowRequester).executionContext

        try await service.processFollow(itemId: itemId, on: context)

        let storedItem = try #require(try await MigrationFollowActivityPubEventItem.find(itemId, on: application.db))
        let storedEvent = try #require(try await MigrationFollowActivityPubEvent.find(eventId, on: application.db))
        #expect(storedItem.status == .succeeded)
        #expect(storedItem.attempts == 1)
        #expect(storedEvent.result == .finished)
        #expect(await outgoingMigrationService.followIds() == [activityId])
    }

    @Test
    func `Cancelling migration should cancel pending items`() async throws {
        let sourceUser = try await application.createUser(userName: "migrationcancelsource", generateKeys: true)
        let targetUser = try await application.createUser(userName: "migrationcanceltarget", isLocal: false)
        let (event, item) = try await self.createMoveEvent(sourceUser: sourceUser,
                                                         targetUser: targetUser,
                                                         inbox: "https://remote-cancel.example/inbox")
        let service = AccountMigrationActivityPubService()
        let context = application.getQueueContext(queueName: .apMoveRequester).executionContext

        try await service.cancel(sourceUserId: sourceUser.requireID(), on: context)

        let storedItem = try #require(try await MigrationMoveActivityPubEventItem.find(item.requireID(), on: application.db))
        let storedEvent = try #require(try await MigrationMoveActivityPubEvent.find(event.requireID(), on: application.db))
        #expect(storedItem.status == .cancelled)
        #expect(storedEvent.result == .cancelled)
    }

    private func createMoveEvent(sourceUser: User,
                                 targetUser: User,
                                 inbox: String) async throws -> (MigrationMoveActivityPubEvent, MigrationMoveActivityPubEventItem) {
        let eventId = application.services.snowflakeService.generate()
        let itemId = application.services.snowflakeService.generate()
        let event = MigrationMoveActivityPubEvent(id: eventId,
                                                  sourceUserId: try sourceUser.requireID(),
                                                  targetUserId: try targetUser.requireID(),
                                                  source: sourceUser.activityPubProfile,
                                                  target: targetUser.activityPubProfile)
        let item = MigrationMoveActivityPubEventItem(id: itemId,
                                                     migrationMoveActivityPubEventId: eventId,
                                                     inbox: inbox)
        try await event.save(on: application.db)
        try await item.save(on: application.db)
        return (event, item)
    }
}
