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
    
    @Suite("Statuses (GET /statuses/:id)", .serialized, .tags(.statuses))
    struct StatusesReadActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Public status should be returned for unauthorized`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinhoower")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let statusDto = try await application.getResponse(
                to: "/statuses/\(status.requireID())",
                method: .GET,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(status.note == statusDto.note, "Status note should be returned.")
            #expect(statusDto.user.userName == "robinhoower", "User should be returned.")
        }

        @Test
        func `Quiet public status should be returned for unauthorized`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "quietreadstatus")
            let attachment = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment])
            }

            let status = try await application.createStatus(user: user,
                                                            note: "QUIET READ STATUS",
                                                            attachmentIds: [attachment.stringId()!],
                                                            visibility: .quietPublic)

            // Act.
            let statusDto = try await application.getResponse(
                to: "/statuses/\(status.requireID())",
                method: .GET,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(statusDto.note == "QUIET READ STATUS", "Quiet public status should be returned.")
        }

        @Test
        func `Followers and mentioned statuses should not be returned for unauthorized`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "privateunauthorizedread")
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }

            let followersStatus = try await application.createStatus(user: user,
                                                                     note: "FOLLOWERS READ HIDDEN",
                                                                     attachmentIds: [attachment1.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)
            let mentionedStatus = try await application.createStatus(user: user,
                                                                     note: "MENTIONED READ HIDDEN",
                                                                     attachmentIds: [attachment2.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            // Act.
            let followersResponse = try await application.getErrorResponse(
                to: "/statuses/\(followersStatus.requireID())",
                method: .GET
            )
            let mentionedResponse = try await application.getErrorResponse(
                to: "/statuses/\(mentionedStatus.requireID())",
                method: .GET
            )

            // Assert.
            #expect(followersResponse.status == HTTPResponseStatus.notFound, "Followers status should not be returned for unauthorized user.")
            #expect(mentionedResponse.status == HTTPResponseStatus.notFound, "Mentioned status should not be returned for unauthorized user.")
        }
        
        @Test
        func `Followers and mentioned statuses should not be returned for authorized user`() async throws {
            // Arrange.
            let owner = try await application.createUser(userName: "privateauthorizedowner")
            let reader = try await application.createUser(userName: "privateauthorizedreader")

            let attachment1 = try await application.createAttachment(user: owner)
            let attachment2 = try await application.createAttachment(user: owner)
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }

            let followersStatus = try await application.createStatus(user: owner,
                                                                     note: "FOLLOWERS AUTH HIDDEN",
                                                                     attachmentIds: [attachment1.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: followersStatus.requireID(), visibility: .followers)
            let mentionedStatus = try await application.createStatus(user: owner,
                                                                     note: "MENTIONED AUTH HIDDEN",
                                                                     attachmentIds: [attachment2.stringId()!],
                                                                     visibility: .public)
            try await application.changeStatusVisibility(statusId: mentionedStatus.requireID(), visibility: .mentioned)

            // Act.
            let followersResponse = try await application.getErrorResponse(
                as: .user(userName: reader.userName, password: "p@ssword"),
                to: "/statuses/\(followersStatus.requireID())",
                method: .GET
            )
            let mentionedResponse = try await application.getErrorResponse(
                as: .user(userName: reader.userName, password: "p@ssword"),
                to: "/statuses/\(mentionedStatus.requireID())",
                method: .GET
            )

            // Assert.
            #expect(followersResponse.status == HTTPResponseStatus.forbidden, "Followers status should not be returned for authorized user.")
            #expect(mentionedResponse.status == HTTPResponseStatus.forbidden, "Mentioned status should not be returned for authorized user.")
        }
    }
}
