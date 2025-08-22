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
    let externalImageUrl = "https://github.com/VernissageApp/VernissageServer/blob/a7f6eae06751ad2b17d86d443d737251db3eadb4/Tests/VernissageServerTests/Assets/001.png?raw=true"
    
    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }
    
    @Test("Correct category should be returned for list of tags.")
    func correctCategoryShouldBeReturnedForListOfTags() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let noteTagDtos = [NoteTagDto(type: "hashtag", name: "Street", href: ""), NoteTagDto(type: "hashtag", name: "Street", href: "")]
        
        // Act.
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, and: [], on: application.db)
        
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
        let category = try await statusesService.getCategory(basedOn: noteTagDtos, and: [], on: application.db)
        
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
    
    @Test("Status should be updated based on updated note from ActivityPub request")
    func statusShouldBeUpdateBasedOnUpdatedNoteFromActivityPubRequest() async throws {
        // Arrange.
        let statusesService = StatusesService()
        let user1 = try await application.createUser(userName: "fortnivolop")
        let user2 = try await application.createUser(userName: "vikivolop")
        
        let category = try await application.getCategory(name: "Sport")
        let (statuses, attachments) = try await application.createStatuses(user: user1,
                                                                           notePrefix: "Local timeline #football and @adam@localhost.com",
                                                                           categoryId: category?.stringId(),
                                                                           amount: 1)
        defer {
            application.clearFiles(attachments: attachments)
        }
        
        _ = try await application.reblogStatus(user: user2, status: statuses.first!)
        
        let statusFromDatabase = try await statusesService.get(id: statuses.first!.requireID(), on: application.db)
        let noteDto = NoteDto(id: statusFromDatabase?.activityPubUrl ?? "",
                              summary: "Content warning",
                              inReplyTo: nil,
                              published: nil,
                              updated: Date().toISO8601String(),
                              url: statusFromDatabase?.activityPubUrl ?? "",
                              attributedTo: "",
                              to: .single(ActorDto(id: "")),
                              cc: .single(ActorDto(id: "")),
                              sensitive: true,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "This is #street new content @gigifoter@localhost.com",
                              attachment: [
                                MediaAttachmentDto(mediaType: "image/png",
                                                   url: externalImageUrl,
                                                   name: "This is name",
                                                   blurhash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
                                                   width: 1706,
                                                   height: 882,
                                                   hdrImageUrl: nil,
                                                   exif: MediaExifDto(make: "Sony",
                                                                      model: "A7IV",
                                                                      lens: "Sigma",
                                                                      createDate: "2025-01-10T10:10:01Z",
                                                                      focalLenIn35mmFilm: "85",
                                                                      fNumber: "1.8",
                                                                      exposureTime: "10",
                                                                      photographicSensitivity: "100",
                                                                      film: "Kodak",
                                                                      latitude: "50.01N",
                                                                      longitude: "18.0E",
                                                                      flash: "Yes",
                                                                      focalLength: "120"),
                                                   location: nil)
                              ],
                              tag: .multiple([
                                NoteTagDto(type: "Mention", name: "@gigifoter@localhost.com", href: "http://localhost:8080/actors/gigifoter"),
                                NoteTagDto(type: "Hashtag", name: "street", href: "http://localhost:8080/hashtags/street")
                              ])
        )
        
        
        // Act.
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let statusAfterUpdate = try await statusesService.update(status: statusFromDatabase!, basedOn: noteDto, on: queueContext.executionContext)
        
        // Assert.
        #expect(statusAfterUpdate.note == "This is #street new content @gigifoter@localhost.com", "Note should be saved in updated status.")
        #expect(statusAfterUpdate.updatedByUserAt?.toISO8601String() == noteDto.updated, "Upadted date should be saved in updated status.")
        #expect(statusAfterUpdate.sensitive == true, "Sensitive should be saved in updated status.")
        #expect(statusAfterUpdate.contentWarning == "Content warning", "Content warning should be saved in updated status.")
        #expect(statusAfterUpdate.category?.name == "Street", "Category should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.count == 1, "New attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.blurhash == "LEHV6nWB2yk8pyo0adR*.7kCMdnj", "Blurhash of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.description == "This is name", "Description of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.originalFile.width == 1706, "Width of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.originalFile.height == 882, "Height of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.make == "Sony", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.model == "A7IV", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.lens == "Sigma", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.createDate == "2025-01-10T10:10:01Z", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.focalLenIn35mmFilm == "85", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.fNumber == "1.8", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.exposureTime == "10", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.photographicSensitivity == "100", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.film == "Kodak", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.latitude == "50.01N", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.longitude == "18.0E", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.flash == "Yes", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.attachments.first?.exif?.focalLength == "120", "Exif make of new attachment should be saved in updated status.")
        #expect(statusAfterUpdate.hashtags.contains(where: { $0.hashtag == "street" }) == true, "Hashtag should be saved in updated status.")
        #expect(statusAfterUpdate.mentions.contains(where: { $0.userName == "gigifoter@localhost.com" }) == true, "Mention should be saved in updated status.")
        
        let statusHistoryFromDatabase = try await application.getStatusHistory(statusId: statusAfterUpdate.requireID())
        #expect(statusHistoryFromDatabase != nil, "Status history should be saved.")
        
        let statusHistory = statusHistoryFromDatabase!
        #expect(statusHistory.note == "Local timeline #football and @adam@localhost.com 1", "Note should be saved in updated status.")
        #expect(statusHistory.sensitive == false, "Sensitive should be saved in history status.")
        #expect(statusHistory.contentWarning == nil, "Content warning should be saved in history status.")
        #expect(statusHistory.category?.name == "Sport", "Category should be saved in history status.")
        #expect(statusHistory.attachments.count == 1, "New attachment should be saved in hisotory status.")
        #expect(statusHistory.attachments.first?.blurhash == "BLURHASH", "Blurhash of new attachment should be saved in history status.")
        #expect(statusHistory.attachments.first?.description == "This is description...", "Description of new attachment should be saved in history status.")
        #expect(statusHistory.attachments.first?.exif?.make == "Sony", "Exif make of new attachment should be saved in history status.")
        #expect(statusHistory.attachments.first?.exif?.model == "A7IV", "Exif make of new attachment should be saved in history status.")
        #expect(statusHistory.attachments.first?.exif?.lens == "Viltrox 85", "Exif make of new attachment should be saved in history status.")
        #expect(statusHistory.attachments.first?.exif?.createDate == "2023-07-13T20:15:35.319+02:00", "Exif make of new attachment should be saved in history status.")
        #expect(statusHistory.hashtags.contains(where: { $0.hashtag == "football" }) == true, "Hashtag should be saved in history status.")
        #expect(statusHistory.mentions.contains(where: { $0.userName == "adam@localhost.com" }) == true, "Mention should be saved in history status.")
        
        let notification = try await application.getNotification(type: .update, to: user2.requireID(), by: user1.requireID(), statusId: statusAfterUpdate.requireID())
        #expect(notification != nil, "Notification about update should be added.")
    }
}
