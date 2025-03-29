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
    
    @Suite("Notifications (POST /notifications/marker/:id)", .serialized, .tags(.notifications))
    struct NotificationsMarkerActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Notifications list should be returned for authorized user")
        func notificationsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "caringebino")
            let user2 = try await application.createUser(userName: "adamgebino")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications Marker", amount: 5)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses[0])
            try await application.favouriteStatus(user: user2, status: statuses[1])
            try await application.favouriteStatus(user: user2, status: statuses[2])
            try await application.favouriteStatus(user: user2, status: statuses[3])
            try await application.favouriteStatus(user: user2, status: statuses[4])
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statuses[2].requireID())
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "caringebino", password: "p@ssword"),
                to: "/notifications/marker/\(notification?.stringId() ?? "")",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let notificationMarker = try await application.getNotificationMarker(user: user1)
            #expect(notificationMarker != nil, "Notification marker should be created.")
            #expect(notificationMarker?.notification.id == notification?.id, "Correct notification marker should be saved.")
        }
        
        @Test("Notifications marker should not be updated for unauthorized user")
        func notificationsMarkerShouldNotBeUpdatedForUnauthorizedUser() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/notifications/marker/63363",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
