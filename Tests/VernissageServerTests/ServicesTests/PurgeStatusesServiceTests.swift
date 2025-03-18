//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues

@Suite("PurgeStatusesService")
struct PurgeStatusesServiceTests {
    
    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Statuses older than 180 days should be purged")
    func statusesOlderThan180DaysShouldBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user = try await application.createUser(userName: "adamgruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Purged", amount: 4)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusCreatedAt(statusId: statuses[1].requireID(), createdAt: Date.ago(days: 181))
        try await application.changeStatusCreatedAt(statusId: statuses[2].requireID(), createdAt: Date.ago(days: 179))
        try await application.changeStatusCreatedAt(statusId: statuses[3].requireID(), createdAt: Date.ago(days: 1))

        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        try await application.changeStatusIsLocal(statusId: statuses[1].requireID(), isLocal: false)
        try await application.changeStatusIsLocal(statusId: statuses[2].requireID(), isLocal: false)
        try await application.changeStatusIsLocal(statusId: statuses[3].requireID(), isLocal: false)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        let status2 = try await application.getStatus(id: statuses[1].requireID())
        let status3 = try await application.getStatus(id: statuses[2].requireID())
        let status4 = try await application.getStatus(id: statuses[3].requireID())
        
        #expect(status1 == nil, "Status created 300 days ago should be deleted")
        #expect(status2 == nil, "Status created 181 days ago should be deleted")
        #expect(status3 != nil, "Status created 179 days ago should not be deleted")
        #expect(status4 != nil, "Status created 1 day ago should not be deleted")
    }
    
    @Test("Local status older than 180 days should not be purged")
    func localStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user = try await application.createUser(userName: "jolkagruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Local status created 300 days ago should not be deleted")
    }
    
    @Test("Boosted remote status older than 180 days should not be purged")
    func boostedRemoteStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user1 = try await application.createUser(userName: "wiolagruszka")
        let user2 = try await application.createUser(userName: "angelikagruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        _ = try await application.reblogStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Boosted remote status older than 180 days should not be purged")
    }
    
    @Test("Locally commented remote status older than 180 days should not be purged")
    func locallyCommentedRemoteStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user1 = try await application.createUser(userName: "maksymiliangruszka")
        let user2 = try await application.createUser(userName: "mareczekgruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        _ = try await application.createStatus(user: user2, note: "Comment to sattus", attachmentIds: [], replyToStatusId: statuses[0].stringId())
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Locally commented remote status older than 180 days should not be purged")
    }
    
    @Test("Favourited remote status older than 180 days should not be purged")
    func favouritedRemoteStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user1 = try await application.createUser(userName: "helgagruszka")
        let user2 = try await application.createUser(userName: "hannagruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        try await application.favouriteStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Favourited remote status older than 180 days should not be purged")
    }
    
    @Test("Featured remote status older than 180 days should not be purged")
    func featuredRemoteStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user1 = try await application.createUser(userName: "tobiaszgruszka")
        let user2 = try await application.createUser(userName: "tamkagruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        _ = try await application.createFeaturedStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Featured remote status older than 180 days should not be purged")
    }
    
    @Test("Bookmarked remote status older than 180 days should not be purged")
    func bookmarkedRemoteStatusesOlderThan180DaysShouldNotBePurged() async throws {
        // Arrange.
        let purgeStatusesService = PurgeStatusesService()

        let user1 = try await application.createUser(userName: "greggruszka")
        let user2 = try await application.createUser(userName: "gargamelgruszka")
        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Purged", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        try await application.changeStatusCreatedAt(statusId: statuses[0].requireID(), createdAt: Date.ago(days: 300))
        try await application.changeStatusIsLocal(statusId: statuses[0].requireID(), isLocal: false)
        try await application.bookmarkStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "PurgeStatusesJob"))
        try await purgeStatusesService.purge(on: queueContext.executionContext)
        
        // Arrange.
        let status1 = try await application.getStatus(id: statuses[0].requireID())
        #expect(status1 != nil, "Bookmarked remote status older than 180 days should not be purged")
    }
}
