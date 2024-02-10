//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class NotificationsMarkerActionTests: CustomTestCase {
    
    func testNotificationsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "caringebino")
        let user2 = try await User.create(userName: "adamgebino")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 5)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        try await Status.favourite(user: user2, status: statuses[0])
        try await Status.favourite(user: user2, status: statuses[1])
        try await Status.favourite(user: user2, status: statuses[2])
        try await Status.favourite(user: user2, status: statuses[3])
        try await Status.favourite(user: user2, status: statuses[4])

        let notification = try await Notification.get(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statuses[2].requireID())

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "caringebino", password: "p@ssword"),
            to: "/notifications/marker/\(notification?.stringId() ?? "")",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")

        let notificationMarker = try await NotificationMarker.get(user: user1)
        XCTAssertNotNil(notificationMarker, "Notification marker should be created.")
        XCTAssertEqual(notificationMarker?.notification.id, notification?.id, "Correct notification marker should be saved.")
    }
    
    func testNotificationsMarkerShouldNotBeUpdatedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/notifications/marker/63363",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}



