//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class StatusesUnbookmarkActionTests: CustomTestCase {
    func testStatusShouldBeUnbookmarkedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinzuza")
        let user2 = try await User.create(userName: "adamzuza")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        try await Status.bookmark(user: user2, status: statuses.first!)
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "adamzuza", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/unbookmark",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.bookmarked, false, "Status should be marked as unbookmarked.")
    }
        
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxzuza")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxzuza", password: "p@ssword"),
            to: "/statuses/123456789/unbookmark",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiquezuza")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/unbookmark",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
