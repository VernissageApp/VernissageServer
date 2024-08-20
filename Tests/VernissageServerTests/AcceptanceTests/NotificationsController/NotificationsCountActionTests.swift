//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class NotificationsCountActionTests: CustomTestCase {
    
    func testNotificationsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "carinboren")
        let user2 = try await User.create(userName: "adamboren")
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
        _ = try await NotificationMarker.create(user: user1, notification: notification!)

        // Act.
        let notificationsCount = try SharedApplication.application().getResponse(
            as: .user(userName: "carinboren", password: "p@ssword"),
            to: "/notifications/count",
            method: .GET,
            decodeTo: NotificationsCountDto.self
        )

        // Assert.
        XCTAssertEqual(notificationsCount.amount, 2, "Counter should return two unreaded notifications.")
    }
    
    func testNotificationsCountShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/notifications/count",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}


