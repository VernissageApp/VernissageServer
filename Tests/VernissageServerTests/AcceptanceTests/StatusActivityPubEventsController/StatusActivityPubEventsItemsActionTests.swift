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
    
    @Suite("StatusActivityPubEvents (GET /status-activity-pub-events/:eventId/items)", .serialized, .tags(.statuseActivityPubEvents))
    struct StatusActivityPubEventsItemsActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of event items should be returned for moderator user")
        func listOfEventItemsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let moderator = try await application.createUser(userName: "robinbenny")
            let user = try await application.createUser(userName: "annabenny")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "robinbenny", password: "p@ssword"),
                to: "/status-activity-pub-events/\(event.requireID())/items",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventItemDto>.self
            )
            
            // Assert.
            #expect(events.total == 12, "Correct total event items should be returned.")
            #expect(events.data.count == 10, "Correct event items list should be returned.")
        }
        
        @Test("List of event items should be returned for administrator user")
        func listOfEventItemsShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let administrator = try await application.createUser(userName: "markbenny")
            let user = try await application.createUser(userName: "monikabenny")
            try await application.attach(user: administrator, role: Role.administrator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "markbenny", password: "p@ssword"),
                to: "/status-activity-pub-events/\(event.requireID())/items",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventItemDto>.self
            )
            
            // Assert.
            #expect(events.total == 12, "Correct total events should be returned.")
            #expect(events.data.count == 10, "Correct events list should be returned.")
        }
        
        @Test("Forbidden should be returned for regulat user")
        func forbiddenShouldBeRturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roksanabenny")
            _ = try await application.createUser(userName: "olabenny")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "olabenny", password: "p@ssword"),
                to: "/status-activity-pub-events/\(event.requireID())/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Bad request should be returned when event id is incorrect")
        func badRequestShouldBeReturnedWhenEventIdIsIncorrect() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "urszulabenny")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "urszulabenny", password: "p@ssword"),
                to: "/status-activity-pub-events/aaa/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(response.error.code == "incorrectStatusEventId", "Error code should be equal 'incorrectStatusEventId'.")
        }
        
        @Test("Not found should be returned when event not exists")
        func notFoundShouldBeReturnedWhenEventNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "alinabenny")
            try await application.attach(user: user, role: Role.administrator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "alinabenny", password: "p@ssword"),
                to: "/status-activity-pub-events/11/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
            #expect(response.error.code == "statusActivityPubEventNotFound", "Error code should be equal 'statusActivityPubEventNotFound'.")
        }
        
        @Test("Events should not be returned when user is not authorized")
        func eventsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "christabenny")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            
            // Act.
            let response = try await application.sendRequest(to: "/status-activity-pub-events/\(event.requireID())/items", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
