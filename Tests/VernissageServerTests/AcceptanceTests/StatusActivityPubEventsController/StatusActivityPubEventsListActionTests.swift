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
    
    @Suite("StatusActivityPubEvents (GET /status-activity-pub-events)", .serialized, .tags(.statuseActivityPubEvents))
    struct StatusActivityPubEventsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("List of events should be returned for moderator user")
        func listOfEventsShouldBeReturnedForModeratorUser() async throws {
            
            // Arrange.
            let moderator = try await application.createUser(userName: "robintrend")
            let user = try await application.createUser(userName: "annatrend")
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
                as: .user(userName: "robintrend", password: "p@ssword"),
                to: "/status-activity-pub-events",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventDto>.self
            )
            
            // Assert.
            #expect(events.total >= 2, "Correct total events should be returned.")
            #expect(events.data.count >= 2, "Correct events list should be returned.")
        }
        
        @Test("List of events should be returned for administrator user")
        func listOfEventsShouldBeReturnedForAdministratorUser() async throws {
            
            // Arrange.
            let administrator = try await application.createUser(userName: "marktrend")
            let user = try await application.createUser(userName: "monikatrend")
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
                as: .user(userName: "marktrend", password: "p@ssword"),
                to: "/status-activity-pub-events",
                method: .GET,
                decodeTo: PaginableResultDto<StatusActivityPubEventDto>.self
            )
            
            // Assert.
            #expect(events.total >= 2, "Correct total events should be returned.")
            #expect(events.data.count >= 2, "Correct events list should be returned.")
        }
                
        @Test("Forbidden should be returned for regular user")
        func forbiddenShouldBeRturnedForRegularUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "roksanatrend")
            _ = try await application.createUser(userName: "olatrend")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user1.requireID(), type: .update)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "olatrend", password: "p@ssword"),
                to: "/status-activity-pub-events",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Events should not be returned when user is not authorized")
        func eventsShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "christatrend")
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note with events", attachmentIds: [attachment.stringId()!], visibility: .public)
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .create)
            _ = try await application.createStatusActivityPubEvent(statusId: status.requireID(), userId: user.requireID(), type: .update)
            
            // Act.
            let response = try await application.sendRequest(to: "/status-activity-pub-events", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
