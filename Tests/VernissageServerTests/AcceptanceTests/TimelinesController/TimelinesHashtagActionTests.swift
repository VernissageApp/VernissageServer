//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Timelines (GET /timelines/hashtag/:hashtag)", .serialized, .tags(.timelines))
    struct TimelinesHashtagActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Statuses should be returned for unauthorized without params when public access is enabled`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "timredix")
            let (_, attachments) = try await application.createStatuses(user: user, notePrefix: "Public note #black #white", amount: 4)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/timelines/hashtag/black?limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Public note #black #white 4", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Public note #black #white 3", "Second status is not visible.")
        }
        
        @Test
        func `Statuses should be returned for unauthorized with minId when public access is enabled`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "tomredix")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Min note #red #yellow", amount: 10)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/timelines/hashtag/red?limit=2&minId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Min note #red #yellow 8", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Min note #red #yellow 7", "Second status is not visible.")
        }
        
        @Test
        func `Statuses should be returned for unauthorized with maxId when public access is enabled`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "ronredix")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Max note #pink #brown", amount: 10)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/timelines/hashtag/pink?limit=2&maxId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 2, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Max note #pink #brown 5", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Max note #pink #brown 4", "Second status is not visible.")
        }
        
        @Test
        func `Statuses should be returned for unauthorized with sinceId when public access is enabled`() async throws {
            
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))
            
            let user = try await application.createUser(userName: "gregredix")
            let (statuses, attachments) = try await application.createStatuses(user: user, notePrefix: "Since note #gray #blue", amount: 10)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/timelines/hashtag/blue?limit=20&sinceId=\(statuses[5].id!)",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.count == 4, "Statuses list should be returned.")
            #expect(statusesFromApi.data[0].note == "Since note #gray #blue 10", "First status is not visible.")
            #expect(statusesFromApi.data[1].note == "Since note #gray #blue 9", "Second status is not visible.")
            #expect(statusesFromApi.data[2].note == "Since note #gray #blue 8", "Third status is not visible.")
            #expect(statusesFromApi.data[3].note == "Since note #gray #blue 7", "Fourth status is not visible.")
        }

        @Test
        func `Only public statuses should be returned on hashtag timeline`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(true))

            let user = try await application.createUser(userName: "hashtagvisibilityuser")

            let publicAttachment = try await application.createAttachment(user: user)
            let quietAttachment = try await application.createAttachment(user: user)
            let followersAttachment = try await application.createAttachment(user: user)
            let mentionedAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [publicAttachment, quietAttachment, followersAttachment, mentionedAttachment])
            }

            _ = try await application.createStatus(user: user,
                                                   note: "Hashtag visibility public #visibilitytest",
                                                   attachmentIds: [publicAttachment.stringId()!],
                                                   visibility: .public)

            let quietStatus = try await application.createStatus(user: user,
                                                                 note: "Hashtag visibility quiet #visibilitytest",
                                                                 attachmentIds: [quietAttachment.stringId()!],
                                                                 visibility: .public)
            try await application.changeStatusVisibility(statusId: quietStatus.requireID(), visibility: .quietPublic)

            let followersStatus = try await application.createStatus(user: user,
                                                                     note: "Hashtag visibility followers #visibilitytest",
                                                                     attachmentIds: [followersAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)

            let mentionedStatus = try await application.createStatus(user: user,
                                                                     note: "Hashtag visibility mentioned #visibilitytest",
                                                                     attachmentIds: [mentionedAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            // Act.
            let statusesFromApi = try await application.getResponse(
                to: "/timelines/hashtag/visibilitytest?limit=20",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            // Assert.
            #expect(statusesFromApi.data.contains(where: { $0.note == "Hashtag visibility public #visibilitytest" }) == true,
                    "Public status should be visible on hashtag timeline.")
            #expect(statusesFromApi.data.contains(where: { $0.note == "Hashtag visibility quiet #visibilitytest" }) == false,
                    "Quiet public status should not be visible on hashtag timeline.")
            #expect(statusesFromApi.data.contains(where: { $0.note == "Hashtag visibility followers #visibilitytest" }) == false,
                    "Followers status should not be visible on hashtag timeline.")
            #expect(statusesFromApi.data.contains(where: { $0.note == "Hashtag visibility mentioned #visibilitytest" }) == false,
                    "Mentioned status should not be visible on hashtag timeline.")
        }
        
        @Test
        func `Statuses should not be returned for unauthorized when public access is disabled`() async throws {
            // Arrange.
            try await application.updateSetting(key: .showHashtagsForAnonymous, value: .boolean(false))
            
            // Act.
            let response = try await application.sendRequest(
                to: "/timelines/hashtag/blue",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test
        func `Statuses from muted account should not be visible for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "orangeredix")
            let user2 = try await application.createUser(userName: "brownredix")
            let (_, attachments1) = try await application.createStatuses(user: user1, notePrefix: "Public note orangeredix #mutedtest", amount: 2)
            let (_, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note brownredix #mutedtest", amount: 2)
            defer {
                application.clearFiles(attachments: attachments1 + attachments2)
            }
            
            _ = try await application.createUserMute(userId: user1.requireID(),
                                                     mutedUserId: user2.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: false,
                                                     muteNotifications: false)
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                as: .user(userName: "orangeredix", password: "p@ssword"),
                to: "/timelines/hashtag/mutedtest",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.contains(where: { $0.note?.contains("orangeredix") == true }) == true, "Not muted user statuses should be visible.")
            #expect(statusesFromApi.data.contains(where: { $0.note?.contains("brownredix") == true }) == false, "Muted user statuses should not be visible.")
        }
        
        @Test
        func `Statuses from blocked account should not be visible for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carolineredix")
            let user2 = try await application.createUser(userName: "victoriaredix")
            let (_, attachments1) = try await application.createStatuses(user: user1, notePrefix: "Public note carolineredix #mutedtest", amount: 2)
            let (_, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note victoriaredix #mutedtest", amount: 2)
            defer {
                application.clearFiles(attachments: attachments1 + attachments2)
            }
            
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user2.requireID(), reason: "")
            
            // Act.
            let statusesFromApi = try await application.getResponse(
                as: .user(userName: "carolineredix", password: "p@ssword"),
                to: "/timelines/hashtag/mutedtest",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statusesFromApi.data.contains(where: { $0.note?.contains("carolineredix") == true }) == true, "Not blocked user statuses should be visible.")
            #expect(statusesFromApi.data.contains(where: { $0.note?.contains("victoriaredix") == true }) == false, "Blocked user statuses should not be visible.")
        }
    }
}
