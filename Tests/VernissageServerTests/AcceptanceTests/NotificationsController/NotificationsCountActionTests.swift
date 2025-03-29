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
    
    @Suite("Notifications (GET /notifications/count)", .serialized, .tags(.notifications))
    struct NotificationsCountActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Notifications list should be returned for authorized user")
        func notificationsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "carinboren")
            let user2 = try await application.createUser(userName: "adamboren")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications Count", amount: 5)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses[0])
            try await application.favouriteStatus(user: user2, status: statuses[1])
            try await application.favouriteStatus(user: user2, status: statuses[2])
            try await application.favouriteStatus(user: user2, status: statuses[3])
            try await application.favouriteStatus(user: user2, status: statuses[4])
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statuses[2].requireID())
            _ = try await application.createNotificationMarker(user: user1, notification: notification!)
            
            // Act.
            let notificationsCount = try await application.getResponse(
                as: .user(userName: "carinboren", password: "p@ssword"),
                to: "/notifications/count",
                method: .GET,
                decodeTo: NotificationsCountDto.self
            )
            
            // Assert.
            #expect(notificationsCount.amount == 2, "Counter should return two unreaded notifications.")
        }
        
        @Test("Notifications count should not be returned for unauthorized user")
        func notificationsCountShouldNotBeReturnedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/notifications/count",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
