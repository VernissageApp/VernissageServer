//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class NotificationsListActionTests: CustomTestCase {
    
    func testNotificationsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "carinroki")
        let user2 = try await User.create(userName: "adamroki")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        try await Status.favourite(user: user2, status: statuses.first!)

        // Act.
        let notifications = try SharedApplication.application().getResponse(
            as: .user(userName: "carinroki", password: "p@ssword"),
            to: "/notifications",
            method: .GET,
            decodeTo: LinkableResultDto<NotificationDto>.self
        )

        // Assert.
        XCTAssert(notifications.data.count > 0, "Notifications list should be returned.")
    }
    
    func testNotificationsListShouldNotBeReturnedForUnauthorizedUser() async throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/notifications",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

