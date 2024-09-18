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

extension NotificationsControllerTests {
    
    @Suite("GET /", .serialized, .tags(.notifications))
    struct NotificationsListActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Notifications list should be returned for authorized user")
        func notificationsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "carinroki")
            let user2 = try await application.createUser(userName: "adamroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses.first!)
            
            // Act.
            let notifications = try application.getResponse(
                as: .user(userName: "carinroki", password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self
            )
            
            // Assert.
            #expect(notifications.data.count > 0, "Notifications list should be returned.")
        }
        
        @Test("Notifications list should not be returned for unauthorized user")
        func notificationsListShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try application.sendRequest(
                to: "/notifications",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
