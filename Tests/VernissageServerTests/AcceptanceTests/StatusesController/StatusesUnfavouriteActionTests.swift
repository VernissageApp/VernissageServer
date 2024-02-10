//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesUnfavouriteActionTests: CustomTestCase {
    func testStatusShouldBeUnfavouritedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinmina")
        let user2 = try await User.create(userName: "adammina")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        try await Status.favourite(user: user2, status: statuses.first!)
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "adammina", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unfavourite",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.favourited, false, "Status should be marked as unfavourited.")
        XCTAssertEqual(statusDto.favouritesCount, 0, "Favourited count should be equal 0.")
        
        let notification = try await Notification.get(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statusDto.id?.toId())
        XCTAssertNil(notification, "Notification should be deleted.")
    }
        
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxmina")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxmina", password: "p@ssword"),
            to: "/statuses/123456789/unfavourite",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiquemina")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unfavourite",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
