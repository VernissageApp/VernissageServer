//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class StatusesBookmarkActionTests: CustomTestCase {
    func testStatusShouldBeBookmarkedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "carinesso")
        _ = try await User.create(userName: "adamesso")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let statusDto = try SharedApplication.application().getResponse(
            as: .user(userName: "adamesso", password: "p@ssword"),
            to: "/statuses/\(statuses.first!.requireID())/bookmark",
            method: .POST,
            decodeTo: StatusDto.self
        )
        
        // Assert.
        XCTAssert(statusDto.id != nil, "Status wasn't created.")
        XCTAssertEqual(statusDto.bookmarked, true, "Status should be marked as bookmarked.")
    }
    
    func testNotFoundShouldBeReturnedForStatusWithMentionedVisibility() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "brosesso")
        _ = try await User.create(userName: "ingaesso")
        let attachment = try await Attachment.create(user: user1)
        let status = try await Status.create(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!], visibility: .mentioned)
        defer {
            Status.clearFiles(attachments: [attachment])
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ingaesso", password: "p@ssword"),
            to: "/statuses/\(status.requireID())/bookmark",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testNotFoundShouldBeReturnedIfStatusNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "maxesso")
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "maxesso", password: "p@ssword"),
            to: "/statuses/123456789/bookmark",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedShouldBeReturnedForNotAuthorizedUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "moiqueesso")
        let (statuses, attachments) = try await Status.createStatuses(user: user1, notePrefix: "Note", amount: 1)
        defer {
            Status.clearFiles(attachments: attachments)
        }
        
        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/statuses/\(statuses.first!.requireID())/bookmark",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
