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
    
    @Suite("Statuses (GET /statuses/:id/events/:eventId/items)", .serialized, .tags(.statuses))
    struct StatusesEventItemsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of event items should be returned for moderator user")
        func listOfEventItemsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let moderator = try await application.createUser(userName: "robingrubson")
            let user = try await application.createUser(userName: "annagrubson")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "robingrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/\(event.requireID())/items",
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
            let administrator = try await application.createUser(userName: "markgrubson")
            let user = try await application.createUser(userName: "monikagrubson")
            try await application.attach(user: administrator, role: Role.administrator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "markgrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/\(event.requireID())/items",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventItemDto>.self
            )
            
            // Assert.
            #expect(events.total == 12, "Correct total events should be returned.")
            #expect(events.data.count == 10, "Correct events list should be returned.")
        }
        
        @Test("List of event items should be returned for status owner")
        func listOfEventItemsShouldBeReturnedForStatusOwner() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "wiktoriagrubson")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "wiktoriagrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/\(event.requireID())/items",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventItemDto>.self
            )
            
            // Assert.
            #expect(events.total == 12, "Correct total events should be returned.")
            #expect(events.data.count == 10, "Correct events list should be returned.")
        }
        
        @Test("Only error items should be returned for only errors filter")
        func onlyErrorItemsShouldBeReturnedForOnlyErrorsFilter() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "filemonagrubson")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create, numberOfSuccessItems: 12, numberOfErrorItems: 14)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "filemonagrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/\(event.requireID())/items?onlyErrors=true",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventItemDto>.self
            )
            
            // Assert.
            #expect(events.total == 14, "Correct total events should be returned.")
            #expect(events.data.count == 10, "Correct events list should be returned.")
        }
        
        @Test("Forbidden should be returned for someone else status events")
        func forbiddenShouldBeRturnedForSomeoneElseStatusEvents() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roksanagrubson")
            _ = try await application.createUser(userName: "olagrubson")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .create, numberOfSuccessItems: 12)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "olagrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/\(event.requireID())/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Bad request should be returned when status id is incorrect")
        func badRequestShouldBeReturnedWhenStatusIdIsIncorrect() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "urszulagrubson")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "urszulagrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/aaa/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(response.error.code == "incorrectStatusEventId", "Error code should be equal 'incorrectStatusEventId'.")
        }
        
        @Test("Not found should be returned when status not exists")
        func notFoundShouldBeReturnedWhenStatusNotExists() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "alinagrubson")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "alinagrubson", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events/11/items",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
            #expect(response.error.code == "statusActivityPubEventNotFound", "Error code should be equal 'statusActivityPubEventNotFound'.")
        }
        
        @Test("Events should not be returned when user is not authorized")
        func eventsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "christagrubson")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let event = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            
            // Act.
            let response = try await application.sendRequest(to: "/statuses/\(status.requireID())/events/\(event.requireID())/items", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
