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
    
    @Suite("Statuses (POST /statuses/:id/unlist)", .serialized, .tags(.statuses))
    struct StatusesUnlistActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be unlisted for authorized user")
        func statusShouldBeUnlistedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brostofiq")
            let user2 = try await application.createUser(userName: "ingatofiq")
            let user3 = try await application.createUser(userName: "romatofiq")
            try await application.attach(user: user3, role: Role.moderator)
            
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
            _ = try await application.createUserStatus(type: .mention, user: user2, status: status)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "romatofiq", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/unlist",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userStatuses = try await application.getAllUserStatuses(for: status.requireID())
            #expect(userStatuses.count == 0, "Statuses should be deleted from user's timelines.")
        }
        
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldbeReturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinetofiq")
            _ = try await application.createUser(userName: "adametofiq")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unlist", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "adametofiq", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unlist",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "maxetofiq")
            try await application.attach(user: user1, role: Role.moderator)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxetofiq", password: "p@ssword"),
                to: "/statuses/123456789/unlist",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiqueetofiq")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unlist Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unlist",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
