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
    
    @Suite("Statuses (GET /statuses/:id/context)", .serialized, .tags(.statuses))
    struct StatusesContextActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status context should be returned for user")
        func statusContextShouldBeReturnedForUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "robintopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            let attachment3 = try await application.createAttachment(user: user)
            let attachment4 = try await application.createAttachment(user: user)
            let attachment5 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], replyToStatusId: status1.stringId())
            let status3 = try await application.createStatus(user: user, note: "Note 3", attachmentIds: [attachment3.stringId()!], replyToStatusId: status2.stringId())
            let status4 = try await application.createStatus(user: user, note: "Note 4", attachmentIds: [attachment4.stringId()!], replyToStatusId: status3.stringId())
            let status5 = try await application.createStatus(user: user, note: "Note 5", attachmentIds: [attachment5.stringId()!], replyToStatusId: status3.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2, attachment3, attachment4, attachment5])
            }
            
            // Act.
            let statusContextDto = try await application.getResponse(
                as: .user(userName: "robintopiq", password: "p@ssword"),
                to: "/statuses/\(status3.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )
            
            // Assert.
            #expect(statusContextDto.ancestors.count > 0, "Status ancestors context should be returned.")
            #expect(statusContextDto.descendants.count > 0, "Status descendants context should be returned.")
            #expect(status1.stringId() == statusContextDto.ancestors[0].id, "First status ancestor should be returned.")
            #expect(status2.stringId() == statusContextDto.ancestors[1].id, "Second status ancestor should be returned.")
            #expect(status4.stringId() == statusContextDto.descendants[0].id, "First status descendant should be returned.")
            #expect(status5.stringId() == statusContextDto.descendants[1].id, "Second status descendant should be returned.")
        }
        
        @Test("Unauthorized should be returned for not authorized not public status")
        func unauthorizedShouldBeReturnedForNotAuthorizedNotPublicStatus() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "komatopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!], visibility: .mentioned)
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], visibility: .mentioned, replyToStatusId: status1.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(status2.requireID())/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Status context should be returned for not authorized user and public status")
        func statusContextShouldBeReturnedForNotAuthorizedUserAndPublicStatus() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "temontopiq")
            
            let attachment1 = try await application.createAttachment(user: user)
            let attachment2 = try await application.createAttachment(user: user)
            
            let status1 = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let status2 = try await application.createStatus(user: user, note: "Note 2", attachmentIds: [attachment2.stringId()!], replyToStatusId: status1.stringId())
            
            defer {
                application.clearFiles(attachments: [attachment1, attachment2])
            }
            
            // Act.
            let statusContextDto = try await application.getResponse(
                to: "/statuses/\(status2.requireID())/context",
                method: .GET,
                decodeTo: StatusContextDto.self
            )
            
            // Assert.
            #expect(statusContextDto.ancestors.count > 0, "Status ancestors context should be returned.")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxtopiq")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxtopiq", password: "p@ssword"),
                to: "/statuses/123456789/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Bad request should be returned if status id is not integer")
        func badRequestShouldBeReturnedIfStatusIdIsNotInteger() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annatopiq")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annatopiq", password: "p@ssword"),
                to: "/statuses/aaa/context",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
    }
}
