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
        
        @Test("List of statuses should be returned for unauthorized")
        func listOfStatusesShouldBeReturnedForUnauthorized() async throws {
            
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
            let statuses = try application.getResponse(
                to: "/statuses?minId=\(lastStatus.stringId() ?? "")&limit=2",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.count == 2, "Statuses list should be returned.")
        }
        
        @Test("Other user private statuses should not be returned")
        func otherUserPrivateStatusesShouldNotBeReturned() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "evelyncyan")
            let attachment1 = try await application.createAttachment(user: user1)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let user2 = try await application.createUser(userName: "fredcyan")
            let attachment2 = try await application.createAttachment(user: user2)
            defer {
                application.clearFiles(attachments: [attachment2])
            }
            
            _ = try await application.createStatus(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .followers)
            _ = try await application.createStatus(user: user2, note: "PRIVATE 2", attachmentIds: [attachment2.stringId()!], visibility: .followers)
            
            // Act.
            let statuses = try application.getResponse(
                as: .user(userName: user1.userName, password: "p@ssword"),
                to: "/statuses?limit=40",
                method: .GET,
                decodeTo: LinkableResultDto<StatusDto>.self
            )
            
            // Assert.
            #expect(statuses.data.filter({ $0.note == "PRIVATE 1" }).first != nil, "Statuses list should contain private statuses signed in user.")
            #expect(statuses.data.filter({ $0.note == "PRIVATE 2" }).first == nil, "Statuses list should not contain private statuses other user.")
        }
    }
}
