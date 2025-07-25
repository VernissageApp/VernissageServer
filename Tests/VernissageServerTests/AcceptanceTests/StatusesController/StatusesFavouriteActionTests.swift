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
    
    @Suite("Statuses (POST /statuses/:id/favourite)", .serialized, .tags(.statuses))
    struct StatusesFavouriteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status should be favourited for authorized user")
        func statusShouldBeFavouritedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carintofi")
            let user2 = try await application.createUser(userName: "adamtofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adamtofi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statusDto.id?.toId())
            #expect(notification != nil, "Notification should be added.")
        }
        
        @Test("Comment should be favourited for authorized user")
        func commentShouldBeFavouritedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "matistofi")
            let user2 = try await application.createUser(userName: "maliktofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.createStatus(user: user2, note: "Super comment", attachmentIds: [], replyToStatusId: statuses.first?.stringId())
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "matistofi", password: "p@ssword"),
                to: "/statuses/\(comment.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user2.requireID(), by: user1.requireID(), statusId: comment.id)
            #expect(notification != nil, "Notification should be added.")
            #expect(notification?.$mainStatus.id != nil, "Notification should contain main status.")
        }
        
        @Test("Favouring own status should not add notification")
        func favouritingOwnStatusShouldNotAddNotification() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "jakobtofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "jakobtofi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user1.requireID(), statusId: statusDto.id?.toId())
            #expect(notification == nil, "Notification should not be added.")
        }
        
        @Test("Forbidden should be returned for status with mentioned visibility")
        func forbiddenShouldBeReturnedForStatusWithMentionedVisibility() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brostofi")
            _ = try await application.createUser(userName: "ingatofi")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "ingatofi", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxtofi")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxtofi", password: "p@ssword"),
                to: "/statuses/123456789/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized should be returned for not authorized user")
        func unauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquetofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
