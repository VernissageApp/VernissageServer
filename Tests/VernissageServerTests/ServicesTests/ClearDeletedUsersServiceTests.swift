//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("ClearDeletedUsersService")
struct ClearDeletedUsersServiceTests {

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Remote user deleted over 7 days ago with attempts below limit should be retried`() async throws {
        // Arrange.
        let clearDeletedUsersService = ClearDeletedUsersService()
        let user = try await application.createUser(userName: "remote-user-clear-1", isLocal: false)
        user.lastDeletionAttemptAt = Date.weekAgo.addingTimeInterval(-60)
        user.deletionAttemptsCount = 1
        try await user.save(on: application.db)
        try await user.delete(on: application.db)

        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ClearDeletedUsersJob"))
        try await clearDeletedUsersService.clear(on: queueContext.executionContext)

        // Assert.
        let userAfterClear = try await application.getUser(id: user.requireID(), withDeleted: true)
        #expect(userAfterClear == nil, "Remote deleted user older than 7 days should be force deleted from database.")
    }

    @Test
    func `Remote user deleted less than 7 days ago should not be retried`() async throws {
        // Arrange.
        let clearDeletedUsersService = ClearDeletedUsersService()
        let user = try await application.createUser(userName: "remote-user-clear-2", isLocal: false)
        user.lastDeletionAttemptAt = Date.now.addingTimeInterval(-(6 * 24 * 60 * 60))
        user.deletionAttemptsCount = 1
        try await user.save(on: application.db)
        try await user.delete(on: application.db)

        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ClearDeletedUsersJob"))
        try await clearDeletedUsersService.clear(on: queueContext.executionContext)

        // Assert.
        let userAfterClear = try await application.getUser(id: user.requireID(), withDeleted: true)
        #expect(userAfterClear != nil, "Remote deleted user younger than 7 days should stay in database.")
    }

    @Test
    func `Remote user with reached attempts limit should not be retried`() async throws {
        // Arrange.
        let clearDeletedUsersService = ClearDeletedUsersService()
        let user = try await application.createUser(userName: "remote-user-clear-3", isLocal: false)
        user.lastDeletionAttemptAt = Date.weekAgo.addingTimeInterval(-60)
        user.deletionAttemptsCount = 3
        try await user.save(on: application.db)
        try await user.delete(on: application.db)

        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ClearDeletedUsersJob"))
        try await clearDeletedUsersService.clear(on: queueContext.executionContext)

        // Assert.
        let userAfterClear = try await application.getUser(id: user.requireID(), withDeleted: true)
        #expect(userAfterClear != nil, "Remote deleted user with attempts at limit should not be retried.")
    }
}
