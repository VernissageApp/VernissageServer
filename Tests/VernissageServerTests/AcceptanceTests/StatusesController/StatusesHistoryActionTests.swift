//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Statuses (GET /statuses/:id/history)", .serialized, .tags(.statuses))
    struct StatusesHistoryActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Status history should be returned for user")
        func statusHistoryShouldBeReturnedForUser() async throws {
            
            // Arrange.
            let categorySport = try await application.getCategory(name: "Sport")

            let user = try await application.createUser(userName: "robingrubi")
            let attachment1 = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Orginal status", attachmentIds: [attachment1.stringId()!], visibility: .public)
            
            let attachemnt2 = try await application.updateStatus(statusId: status.requireID(),
                                                                 user: user,
                                                                 note: "This is first update",
                                                                 categoryId: categorySport?.stringId())
            
            let attachemnt3 = try await application.updateStatus(statusId: status.requireID(),
                                                                 user: user,
                                                                 note: "This is second update",
                                                                 categoryId: categorySport?.stringId())

            defer {
                application.clearFiles(attachments: [attachment1, attachemnt2, attachemnt3])
            }
            
            // Act.
            let statusDtos = try await application.getResponse(
                as: .user(userName: "robingrubi", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/history",
                method: .GET,
                decodeTo: [StatusDto].self
            )
            
            // Assert.
            #expect(statusDtos.count == 2, "History should contain two statuses.")
            #expect(statusDtos[0].note == "This is first update", "Second modification should be returned first.")
            #expect(statusDtos[1].note == "Orginal status", "Orginal status should be returned at the end of the list.")
        }
        
        @Test("Unauthorized should be returned for not authorized not public status")
        func unauthorizedShouldBeReturnedForNotAuthorizedNotPublicStatus() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "komagrubi")
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)

            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(status.requireID())/history",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Status history should be returned for not authorized user and public status")
        func statusHistoryShouldBeReturnedForNotAuthorizedUserAndPublicStatus() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "temontgrubi")
            
            let attachment1 = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment1.stringId()!])
            let attachemnt2 = try await application.updateStatus(statusId: status.requireID(), user: user, note: "This is first update")
            
            defer {
                application.clearFiles(attachments: [attachment1, attachemnt2])
            }
            
            // Act.
            let statusDtos = try await application.getResponse(
                to: "/statuses/\(status.requireID())/history",
                method: .GET,
                decodeTo: [StatusDto].self
            )
            
            // Assert.
            #expect(statusDtos.count == 1, "Status history context should be returned.")
        }
        
        @Test("Not found should be returned if status not exists")
        func notFoundShouldBeReturnedIfStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxgrubi")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxgrubi", password: "p@ssword"),
                to: "/statuses/123456789/history",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Bad request should be returned if status id is not integer")
        func badRequestShouldBeReturnedIfStatusIdIsNotInteger() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annagrubi")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "annagrubi", password: "p@ssword"),
                to: "/statuses/aaa/history",
                method: .GET
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
    }
}
