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
        
        @Test("Status should be returned for unauthorized")
        func statusShouldBeReturnedForUnauthorized() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robinhoower")
            let attachment1 = try await application.createAttachment(user: user)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            
            // Act.
            let statusDto = try application.getResponse(
                to: "/statuses/\(status.requireID())",
                method: .GET,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto != nil, "Status should be returned.")
            #expect(status.note == statusDto.note, "Status note should be returned.")
            #expect(statusDto.user.userName == "robinhoower", "User should be returned.")
        }
                
        @Test("Other user private status should not be returned")
        func otherUserPrivateStatusShouldNotBeReturned() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "evelynhoower")
            let user2 = try await application.createUser(userName: "fredhoower")
            
            let attachment1 = try await application.createAttachment(user: user1)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: user2.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Own private status should be returned")
        func ownPrivateStatusShouldBeReturned() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "stanhoower")
            let attachment1 = try await application.createAttachment(user: user1)
            defer {
                application.clearFiles(attachments: [attachment1])
            }
            
            let status = try await application.createStatus(user: user1, note: "PRIVATE 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)
            
            // Act.
            let statusDto = try application.getResponse(
                as: .user(userName: user1.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())",
                method: .GET,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto != nil, "Status should be returned.")
        }
    }
}
