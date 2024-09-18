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

extension StatusesControllerTests {
    
    @Suite("GET /:id/reblog", .serialized, .tags(.statuses))
    struct StatusesReblogActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Status should be reblogged for authorized user")
        func statusShouldBeRebloggedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "caringrox")
            let user2 = try await application.createUser(userName: "adamgrox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let createdStatusDto = try application.getResponse(
                as: .user(userName: "adamgrox", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/reblog",
                method: .POST,
                data: ReblogRequestDto(visibility: .public),
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(createdStatusDto.id != nil, "Status wasn't created.")
            #expect(createdStatusDto.reblogged == true, "Status should be marked as reblogged.")
            #expect(createdStatusDto.reblogsCount == 1, "Reblogged count should be equal 1.")
            
            let notification = try await application.getNotification(type: .reblog, to: user1.requireID(), by: user2.requireID(), statusId: createdStatusDto.id?.toId())
            #expect(notification != nil, "Notification should be added.")
        }
        
        @Test("Forbidden should be returned for status with mentioned visibility")
        func forbiddenShouldBeReturnedForStatusWithMentionedVisibility() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brosgrox")
            let user2 = try await application.createUser(userName: "ingagrox")
            
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
            _ = try await application.createUserStatus(type: .mention, user: user2, status: status)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "ingagrox", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/reblog",
                method: .POST,
                data: ReblogRequestDto(visibility: .public)
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxgrox")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "maxgrox", password: "p@ssword"),
                to: "/statuses/123456789/reblog",
                method: .POST,
                data: ReblogRequestDto(visibility: .public)
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquegrox")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/reblog",
                method: .POST,
                data: ReblogRequestDto(visibility: .public)
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
