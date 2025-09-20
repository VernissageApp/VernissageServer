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
    
    @Suite("Statuses (GET /statuses/:id/events)", .serialized, .tags(.statuses))
    struct StatusesEventsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of events should be returned for moderator user")
        func listOfEventsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let moderator = try await application.createUser(userName: "robinopium")
            let user = try await application.createUser(userName: "annaopium")
            try await application.attach(user: moderator, role: Role.moderator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .update)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "robinopium", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventDto>.self
            )
            
            // Assert.
            #expect(events.total == 2, "Correct total events should be returned.")
            #expect(events.data.count == 2, "Correct events list should be returned.")
        }
        
        @Test("List of events should be returned for administrator user")
        func listOfEventsShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let administrator = try await application.createUser(userName: "markopium")
            let user = try await application.createUser(userName: "monikaopium")
            try await application.attach(user: administrator, role: Role.administrator)
            
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .update)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "markopium", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventDto>.self
            )
            
            // Assert.
            #expect(events.total == 2, "Correct total events should be returned.")
            #expect(events.data.count == 2, "Correct events list should be returned.")
        }
        
        @Test("List of events should be returned for status owner")
        func listOfEventsShouldBeReturnedForStatusOwner() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "wiktoriaopium")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .update)
            
            // Act.
            let events = try await application.getResponse(
                as: .user(userName: "wiktoriaopium", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventDto>.self
            )
            
            // Assert.
            #expect(events.total == 2, "Correct total events should be returned.")
            #expect(events.data.count == 2, "Correct events list should be returned.")
        }
        
        @Test("Forbidden should be returned for someone else status events")
        func forbiddenShouldBeRturnedForSomeoneElseStatusEvents() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roksanaopium")
            _ = try await application.createUser(userName: "olaopium")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .update)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "olaopium", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/events",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Bad request should be returned when status id is incorrect")
        func badRequestShouldBeReturnedWhenStatusIdIsIncorrect() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "urszulaopium")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "urszulaopium", password: "p@ssword"),
                to: "/statuses/aaa/events",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(response.error.code == "incorrectStatusId", "Error code should be equal 'incorrectStatusId'.")
        }
        
        @Test("Not found should be returned when status not exists")
        func notFoundShouldBeReturnedWhenStatusNotExists() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "alinaopium")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "alinaopium", password: "p@ssword"),
                to: "/statuses/11/events",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
            #expect(response.error.code == "statusNotFound", "Error code should be equal 'statusNotFound'.")
        }
        
        @Test("Events should not be returned when user is not authorized")
        func eventsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "christaopium")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .update)
            
            // Act.
            let response = try await application.sendRequest(to: "/statuses/\(status.requireID())/events", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
