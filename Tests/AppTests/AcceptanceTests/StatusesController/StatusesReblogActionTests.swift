//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesReblogActionTests: CustomTestCase {
    func testStatusShouldBeRebloggedForAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "caringrox")
        _ = try await User.create(userName: "adamgrox")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let createdStatusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "caringrox", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/reblog",
            method: .POST,
            data: ReblogRequestDto(visibility: .public),
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(createdStatusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(createdStatusDto.reblogged, true, "Status should be marked as reblogged.")
        XCTAssertEqual(createdStatusDto.reblogsCount, 1, "Reblogged count should be equal 1.")
    }
    
    func testForbiddenShouldBeReturnedForStatusWithMentionedVisibility() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "brosgrox")
        let user2 = try await User.create(userName: "ingagrox")
        
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        _ = try await UserStatus.create(user: user2, status: status)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ingagrox", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/reblog",
            method: .POST,
            data: ReblogRequestDto(visibility: .public)
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testForbiddenShouldBeReturnedIfAccountNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxgrox")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxgrox", password: "p@ssword"),
            to: "/statuses/123456789/reblog",
            method: .POST,
            data: ReblogRequestDto(visibility: .public)
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
