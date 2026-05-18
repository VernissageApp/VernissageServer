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
    
    @Suite("Statuses (GET /statuses)", .serialized, .tags(.statuses))
    struct StatusesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of statuses should be returned for unauthorized`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robincyan")
            
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let attachment2 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment2])
            }
            
            let attachment3 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment3])
            }
            
            let lastStatus = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            _ = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!])
            _ = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!])
            
            // Act.
            let statuses = try await application.getResponse(
                to: "/statuses?minId=\(lastStatus.stringId() ?? "")&limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.count == 2, "Statuses list should be returned.")
        }
        
        @Test
        func `Public statuses and all own statuses should be returned for authorized user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "visibilitylistowner")
            let otherUser = try await application.createUser(userName: "visibilitylistother")

            let publicAttachment = try await application.createAttachment(user: user)
            let quietAttachment = try await application.createAttachment(user: user)
            let followersAttachment = try await application.createAttachment(user: user)
            let mentionedAttachment = try await application.createAttachment(user: user)
            let otherFollowersAttachment = try await application.createAttachment(user: otherUser)
            let otherMentionedAttachment = try await application.createAttachment(user: otherUser)
            defer {
                application.clearFiles(attachments: [publicAttachment,
                                                     quietAttachment,
                                                     followersAttachment,
                                                     mentionedAttachment,
                                                     otherFollowersAttachment,
                                                     otherMentionedAttachment])
            }

            _ = try await application.createStatus(user: user,
                                                   note: "LIST PUBLIC",
                                                   attachmentIds: [publicAttachment.stringId()!],
                                                   visibility: .public)

            _ = try await application.createStatus(user: user,
                                                   note: "LIST QUIET",
                                                   attachmentIds: [quietAttachment.stringId()!],
                                                   visibility: .quietPublic)

            let followersStatus = try await application.createStatus(user: user,
                                                                     note: "LIST FOLLOWERS",
                                                                     attachmentIds: [followersAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)

            let mentionedStatus = try await application.createStatus(user: user,
                                                                     note: "LIST MENTIONED",
                                                                     attachmentIds: [mentionedAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            let otherFollowersStatus = try await application.createStatus(user: otherUser,
                                                                          note: "LIST OTHER FOLLOWERS",
                                                                          attachmentIds: [otherFollowersAttachment.stringId()!],
                                                                          visibility: .public)
            try await application.changeStatusVisibility(statusId: otherFollowersStatus.requireID(), visibility: .followers)

            let otherMentionedStatus = try await application.createStatus(user: otherUser,
                                                                          note: "LIST OTHER MENTIONED",
                                                                          attachmentIds: [otherMentionedAttachment.stringId()!],
                                                                          visibility: .public)
            try await application.changeStatusVisibility(statusId: otherMentionedStatus.requireID(), visibility: .mentioned)
            
            // Act.
            let statuses = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/statuses?limit=40",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.contains(where: { $0.note == "LIST PUBLIC" }) == true, "Public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "LIST QUIET" }) == true, "Quiet public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "LIST FOLLOWERS" }) == true, "Own followers status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "LIST MENTIONED" }) == true, "Own mentioned status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "LIST OTHER FOLLOWERS" }) == false, "Other user followers status should not be returned.")
            #expect(statuses.data.contains(where: { $0.note == "LIST OTHER MENTIONED" }) == false, "Other user mentioned status should not be returned.")
        }

        @Test
        func `Only public and quiet public statuses should be returned for unauthorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "visibilitylistanonymous")

            let publicAttachment = try await application.createAttachment(user: user)
            let quietAttachment = try await application.createAttachment(user: user)
            let followersAttachment = try await application.createAttachment(user: user)
            let mentionedAttachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [publicAttachment, quietAttachment, followersAttachment, mentionedAttachment])
            }

            _ = try await application.createStatus(user: user,
                                                   note: "ANON LIST PUBLIC",
                                                   attachmentIds: [publicAttachment.stringId()!],
                                                   visibility: .public)

            _ = try await application.createStatus(user: user,
                                                   note: "ANON LIST QUIET",
                                                   attachmentIds: [quietAttachment.stringId()!],
                                                   visibility: .quietPublic)

            let followersStatus = try await application.createStatus(user: user,
                                                                     note: "ANON LIST FOLLOWERS",
                                                                     attachmentIds: [followersAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)

            let mentionedStatus = try await application.createStatus(user: user,
                                                                     note: "ANON LIST MENTIONED",
                                                                     attachmentIds: [mentionedAttachment.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            // Act.
            let statuses = try await application.getResponse(
                to: "/statuses?limit=40",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )

            // Assert.
            #expect(statuses.data.contains(where: { $0.note == "ANON LIST PUBLIC" }) == true, "Public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "ANON LIST QUIET" }) == true, "Quiet public status should be returned.")
            #expect(statuses.data.contains(where: { $0.note == "ANON LIST FOLLOWERS" }) == false, "Followers status should not be returned.")
            #expect(statuses.data.contains(where: { $0.note == "ANON LIST MENTIONED" }) == false, "Mentioned status should not be returned.")
        }
    }
}
