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
    
    @Suite("Notifications (GET /notifications)", .serialized, .tags(.notifications))
    struct NotificationsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Notifications list should be returned for authorized user")
        func notificationsListShouldBeReturnedForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "carinroki")
            let user2 = try await application.createUser(userName: "adamroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications List", amount: 1)
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
            #expect(notifications.data.first?.createdAt != nil, "Date of the notification should be returned")
        }
        
        @Test("Notifications list should be returned with main status for comments")
        func notificationsListShouldBeReturnedWithMainStatusForComments() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "mariaroki")
            let user2 = try await application.createUser(userName: "monikaroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.createStatus(user: user2, note: "Super comment", attachmentIds: [], replyToStatusId: statuses.first?.stringId())
            try await application.favouriteStatus(user: user1, status: comment)
            
            // Act.
            let notifications = try application.getResponse(
                as: .user(userName: "monikaroki", password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self
            )
            
            // Assert.
            #expect(notifications.data.count > 0, "Notifications list should be returned.")
            #expect(notifications.data.first?.mainStatus != nil, "Notification should contain main status.")
            #expect(notifications.data.first?.mainStatus?.id == statuses.first?.stringId(), "Notification should containt correct main status.")
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
