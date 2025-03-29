//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
@testable import ActivityPubKit
import Vapor
import Testing
import Queues

@Suite("StatusesService")
struct StatusesServiceTests {

    var application: Application!
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Correct category should be returned for list of tags.")
    func correctCategoryShouldBeReturnedForListOfTags() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let noteTagDtos = [NoteTagDto(type: "hashtag", name: "Street", href: ""), NoteTagDto(type: "hashtag", name: "Street", href: "")]
        
        // Act.
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, on: application.db)
        
        // Assert.
        #expect(category?.name == "Street", "Street category should be returned.")
    }
    
    @Test("Higher priority category should be returned for list of tags.")
    func higherPriorityCategoryShouldBeReturnedForListOfTags() async throws {
        // Arrange.
        let statusesService = StatusesService()
        try await self.application.setCategoryPriority(name: "Animals", priority: 1)
        try await self.application.setCategoryPriority(name: "Nature", priority: 2)
        let noteTagDtos = [NoteTagDto(type: "hashtag", name: "nature", href: ""), NoteTagDto(type: "hashtag", name: "pet", href: "")]
        
        // Act.
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, on: application.db)
        
        // Assert.
        #expect(category?.name == "Animals", "Animals category should be returned.")
    }
    
    @Test("New status should be added to user's timeline when author is not muted.")
    func newStatusShouldBeAddedToUsersTimelineWhenAuthorIsNotMuted() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "robinvolop")
        let user2 = try await application.createUser(userName: "annavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user1.requireID(), status: statuses.first!, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: statuses.first!.requireID())
        #expect(userStatuses.count == 1, "Statuses should be added to user's timelines.")
    }
    
    @Test("New status should be added to user's timeline when author is muted in the past.")
    func newStatusShouldBeAddedToUsersTimelineWhenAuthorIsMutedInThePast() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "veronvolop")
        let user2 = try await application.createUser(userName: "zofiavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user2.requireID(), mutedUserId: user1.requireID(), muteStatuses: true, muteReblogs: true, muteNotifications: true, muteEnd: Date.yesterday)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user1.requireID(), status: statuses.first!, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: statuses.first!.requireID())
        #expect(userStatuses.count == 1, "Statuses should be added to user's timelines.")
    }
    
    @Test("Rebloged status should be added to user's timeline when author reblogs are not muted.")
    func reblogedStatusShouldBeAddedToUsersTimelineWhenAuthorReblogsAreNotMuted() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "viktorvolop")
        let user2 = try await application.createUser(userName: "brianvolop")
        let user3 = try await application.createUser(userName: "oliviavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user2.requireID(), approved: true)
        let reblogStatus = try await application.reblogStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user2.requireID(), status: reblogStatus, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: reblogStatus.requireID())
        #expect(userStatuses.count == 1, "Statuses should be added to user's timelines.")
    }
    
    @Test("New status should not be added to user's timeline when author is muted.")
    func newStatusShouldNotBeAddedToUsersTimelineWhenAuthorIsMuted() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "marcinvolop")
        let user2 = try await application.createUser(userName: "karolinavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user2.requireID(), mutedUserId: user1.requireID(), muteStatuses: true, muteReblogs: false, muteNotifications: false)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user1.requireID(), status: statuses.first!, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: statuses.first!.requireID())
        #expect(userStatuses.count == 0, "Statuses should be added to user's timelines.")
    }
    
    @Test("New status should be added to user's timeline when author is muted only reblogs.")
    func newStatusShouldBeAddedToUsersTimelineWhenAuthorIsMutedOnlyReblogs() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "karolvolop")
        let user2 = try await application.createUser(userName: "weronikavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user2.requireID(), mutedUserId: user1.requireID(), muteStatuses: false, muteReblogs: true, muteNotifications: false)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user1.requireID(), status: statuses.first!, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: statuses.first!.requireID())
        #expect(userStatuses.count == 1, "Statuses should be added to user's timelines.")
    }
    
    @Test("New status should be added to user's timeline when author is muted only notifications.")
    func newStatusShouldBeAddedToUsersTimelineWhenAuthorIsMutedOnlyNotifications() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "marianvolop")
        let user2 = try await application.createUser(userName: "grazavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user2.requireID(), mutedUserId: user1.requireID(), muteStatuses: false, muteReblogs: false, muteNotifications: true)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user1.requireID(), status: statuses.first!, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: statuses.first!.requireID())
        #expect(userStatuses.count == 1, "Statuses should be added to user's timelines.")
    }
    
    @Test("Reblog status should not be added to user's timeline when author reblogs are muted.")
    func reblogStatusShouldNotBeAddedToUsersTimelineWhenAuthorReblogsAreMuted() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "robertvolop")
        let user2 = try await application.createUser(userName: "tobiasztvolop")
        let user3 = try await application.createUser(userName: "urszulavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user3.requireID(), mutedUserId: user2.requireID(), muteStatuses: false, muteReblogs: true, muteNotifications: false)
        
        let reblogStatus = try await application.reblogStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user2.requireID(), status: reblogStatus, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: reblogStatus.requireID())
        #expect(userStatuses.count == 0, "Statuses should be added to user's timelines.")
    }
    
    @Test("Reblog status should not be added to user's timeline when status author is muted.")
    func reblogStatusShouldNotBeAddedToUsersTimelineWhenStatusAuthorIsMuted() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "boboyvolop")
        let user2 = try await application.createUser(userName: "petervolop")
        let user3 = try await application.createUser(userName: "iwonavolop")

        let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Local timeline", amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.createFollow(sourceId: user3.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await application.createUserMute(userId: user3.requireID(), mutedUserId: user1.requireID(), muteStatuses: true, muteReblogs: false, muteNotifications: false)
        
        let reblogStatus = try await application.reblogStatus(user: user2, status: statuses.first!)
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        try await statusesService.createOnLocalTimeline(followersOf: user2.requireID(), status: reblogStatus, on: queueContext.executionContext)
        
        // Assert.
        let userStatuses = try await application.getAllUserStatuses(for: reblogStatus.requireID())
        #expect(userStatuses.count == 0, "Statuses should be added to user's timelines.")
    }
}
