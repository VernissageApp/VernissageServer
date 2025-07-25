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
    
    @Suite("Statuses (POST /statuses/:id/bookmark)", .serialized, .tags(.statuses))
    struct StatusesBookmarkActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be bookmarked for authorized user")
        func statusShouldBeBookmarkedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinesso")
            _ = try await application.createUser(userName: "adamesso")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Bookmarked", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adamesso", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/bookmark",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.bookmarked == true, "Status should be marked as bookmarked.")
        }
        
        @Test("Forbidden should be returned for status with mentioned visibility")
        func forbiddenShouldBeReturnedForStatusWithMentionedVisibility() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brosesso")
            _ = try await application.createUser(userName: "ingaesso")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "ingaesso", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxesso")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxesso", password: "p@ssword"),
                to: "/statuses/123456789/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiqueesso")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Bookmarked Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/bookmark",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
